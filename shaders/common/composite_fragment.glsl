#define ENABLE_OUTLINE 1 // [0 1]

#include "/lib/config.glsl"
const bool colortex1MipmapEnabled = true;

#ifdef THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

uniform sampler2D colortex1;
uniform float far;
uniform float near;
uniform float blindness;
uniform float rainStrength;
uniform sampler2D depthtex0;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#if VOL_LIGHT == 1 && !defined NETHER
    uniform sampler2D depthtex1;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform float dayNightMix;
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 gbufferModelView;
    uniform float volumetricDayMixer;
#endif

#if VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER
    uniform float dayNightMix;
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 gbufferModelView;
    uniform float volumetricDayMixer;
    uniform vec3 shadowLightPosition;
    uniform mat4 shadowModelView;
    uniform mat4 shadowProjection;
    uniform sampler2DShadow shadowtex1;

    #if defined COLORED_SHADOW
        uniform sampler2DShadow shadowtex0;
        uniform sampler2D shadowcolor0;
    #endif
#endif

#define outline_threshold 0.0001
#define outline_rim_offset 0.001
#define outline_screen_value 2000.0
#define outline_mode 1
#define outline_max_distance 50.0
#define outline_ramp_value 0.001

varying vec2 texcoord;
varying vec3 directLightColor;
varying float exposure;

#if VOL_LIGHT == 1 && !defined NETHER
    varying vec3 volumetricLightColor;
    varying vec2 lightpos;
    varying vec3 astroLightPos;
#endif

#if VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER
    varying vec3 volumetricLightColor;
#endif

#if (VOL_LIGHT == 1 && !defined NETHER) || (VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER)
    varying mat4 modeli_times_projectioni;
#endif

#include "/lib/basic_utils.glsl"
#include "/lib/depth.glsl"

#ifdef BLOOM
    #include "/lib/luma.glsl"
#endif

#if VOL_LIGHT == 1 && !defined NETHER
    #include "/lib/dither.glsl"
    #include "/lib/volumetric_light.glsl"
#endif

#if VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER
    #include "/lib/dither.glsl"
    #include "/lib/volumetric_light.glsl"
#endif

float getRimIntensity(float depthOft1, float depthOft2, float depth) {
    float depthDiffer1 = (depthOft1 - depth) * float(outline_mode);
    float depthDiffer2 = (depthOft2 - depth) * float(outline_mode);

    float rimIntensity1 = step(outline_threshold, depthDiffer1);
    float rimIntensity2 = step(outline_threshold, depthDiffer2);
    float rimIntensity = max(rimIntensity1, rimIntensity2);

    float isRamp = step(outline_ramp_value, abs(depthDiffer1 + depthDiffer2));

    return min(rimIntensity, isRamp);
}

void main() {
    vec4 blockColor = texture2DLod(colortex1, texcoord, 0);
    float d = texture2DLod(depthtex0, texcoord, 0).r;
    float linearDepth = ld(d);

    vec2 eyeBrightSmoothFloat = vec2(eyeBrightnessSmooth);

    float screen_distance = linearDepth * far * 0.5;

    if(isEyeInWater == 1) {
        float waterAbsorption = clamp(1.0 - pow(1.001 - linearDepth, 5.0 + (4.0 * WATER_ABSORPTION)), 0.0, 1.0);

        blockColor.rgb =
            mix(blockColor.rgb, WATER_COLOR * directLightColor * ((eyeBrightSmoothFloat.y * .8 + 48) * 0.004166666666666667), waterAbsorption);

    } else if(isEyeInWater == 2) {
        blockColor = mix(blockColor, vec4(1.0, .1, 0.0, 1.0), clamp(sqrt(linearDepth * far * 0.125), 0.0, 1.0));
    }

    #if MC_VERSION >= 11900
        if((blindness > .01 || darknessFactor > .01) && linearDepth > 0.9) {
            blockColor.rgb = vec3(0.0);
        }
    #else
        if(blindness > .01 && linearDepth > 0.999) {
            blockColor.rgb = vec3(0.0);
        }
    #endif

    #if (VOL_LIGHT == 1 && !defined NETHER) || (VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER)
        #if AA_TYPE > 0
           float dither = shiftedDither17(gl_FragCoord.xy);
        #else
            float dither = rDither(gl_FragCoord.xy);
        #endif
    #endif

    #if VOL_LIGHT == 1 && !defined NETHER
        #if defined THE_END
            float volumetricLight = 0.1;
            if(d > 0.9999) {
                volumetricLight = 0.5;
            }
        #else
            float volumetricLight = ssGodrays(dither);
        #endif

        vec4 centerFarPlanePos = modeli_times_projectioni * (vec4(0.5, 0.5, 1.0, 1.0) * 2.0 - 1.0);
        vec3 centerEyeDirection = normalize(centerFarPlanePos.xyz);

        vec4 farPlaneClipPos = modeli_times_projectioni * (vec4(texcoord, 1.0, 1.0) * 2.0 - 1.0);
        vec3 eyeDirection = normalize(farPlaneClipPos.xyz);

        #if defined THE_END
            vec3 auxVector =
                normalize((gbufferModelViewInverse * gbufferModelView * vec4(0.0, 0.89442719, 0.4472136, 0.0)).xyz);
            float volumetricIntensity =
                clamp(dot(centerEyeDirection, auxVector), 0.0, 1.0);

            volumetricIntensity *= clamp(dot(eyeDirection, auxVector), 0.0, 1.0);

            volumetricIntensity *= 0.666;

            blockColor.rgb += (volumetricLightColor * volumetricLight * volumetricIntensity * 2.0);
        #else
            vec3 auxVector =
                normalize((gbufferModelViewInverse * vec4(astroLightPos, 0.0)).xyz);
            float lightDot = dot(eyeDirection, auxVector);
            float volumetricIntensity = clamp(lightDot, 0.0, 1.0);
            volumetricIntensity = max(volumetricIntensity, 0.15);
            volumetricIntensity =
                pow(volumetricIntensity, volumetricDayMixer) * 0.5 * abs(dayNightMix * 2.0 - 1.0);

            blockColor.rgb =
                mix(blockColor.rgb, volumetricLightColor * volumetricLight,
                    volumetricIntensity * (volumetricLight * 0.5 + 0.5) * (1.0 - rainStrength));
        #endif
    #endif

    #if VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER
        #if defined COLORED_SHADOW
            vec3 volumetricLight = get_volumetric_color_light(dither, screen_distance, modeli_times_projectioni);
        #else
            float volumetricLight = get_volumetric_light(dither, screen_distance, modeli_times_projectioni);
        #endif

        vec4 farPlaneClipPos = modeli_times_projectioni * (vec4(texcoord, 1.0, 1.0) * 2.0 - 1.0);
        vec3 eyeDirection = normalize(farPlaneClipPos.xyz);

        #if defined THE_END
            float volumetricIntensity = dot(eyeDirection, normalize((gbufferModelViewInverse * gbufferModelView * vec4(0.0, 0.89442719, 0.4472136, 0.0)).xyz));
            volumetricIntensity =
                ((squarePow(clamp((volumetricIntensity + .666667) * 0.6, 0.0, 1.0)) * 0.5));
            blockColor.rgb += (volumetricLightColor * volumetricLight * volumetricIntensity * 2.0);
        #else
            float volumetricIntensity = dot(eyeDirection, normalize((gbufferModelViewInverse * vec4(shadowLightPosition, 0.0)).xyz));
            volumetricIntensity =
                pow(clamp((volumetricIntensity + 0.5) * 0.666666666666666, 0.0, 1.0), volumetricDayMixer) * 0.6 * abs(dayNightMix * 2.0 - 1.0);

            blockColor.rgb =
                mix(blockColor.rgb, volumetricLightColor * volumetricLight,
                    volumetricIntensity * (volumetricLight * 0.5 + 0.5) * (1.0 - rainStrength));
        #endif
    #endif

    #ifdef BLOOM
        if(isEyeInWater == 3) {
            blockColor.rgb =
                mix(blockColor.rgb, vec3(0.7, 0.8, 1.0) / exposure, clamp(screen_distance, 0.0, 1.0));
        }
    #else
        if(isEyeInWater == 3) {
            blockColor.rgb =
                mix(blockColor.rgb, vec3(0.85, 0.9, 0.6), clamp(screen_distance, 0.0, 1.0));
        }
    #endif

    vec2 texelSize = 1.0 / vec2(textureSize(depthtex0, 0));
    vec2 offset = texelSize * outline_rim_offset * outline_screen_value;   

    float depthCenter = d;
    float depthLeft   = texture2D(depthtex0, texcoord + vec2(-offset.x, 0.0)).r;
    float depthRight  = texture2D(depthtex0, texcoord + vec2( offset.x, 0.0)).r;
    float depthUp     = texture2D(depthtex0, texcoord + vec2(0.0,  offset.y)).r;
    float depthDown   = texture2D(depthtex0, texcoord + vec2(0.0, -offset.y)).r;

    float ldCenter = linearDepth;
    float ldLeft   = ld(depthLeft);
    float ldRight  = ld(depthRight);
    float ldUp     = ld(depthUp);
    float ldDown   = ld(depthDown);

    float rimIntensityV = getRimIntensity(ldLeft, ldRight, ldCenter);
    float rimIntensityH = getRimIntensity(ldUp,   ldDown,   ldCenter);
    float rimIntensity = max(rimIntensityV, rimIntensityH);
    float dist = linearDepth * far;
    #if ENABLE_OUTLINE == 1
        if (d < 0.9999 && rimIntensity == 1.0 && dist < outline_max_distance) {
            blockColor.rgb = vec3(0.0);  
        }
    #endif

    #ifdef BLOOM
        float bloom_luma = smoothstep(0.85, 1.0, luma(blockColor.rgb * exposure)) * 0.5;

        blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));
        /* DRAWBUFFERS:016 */
        gl_FragData[0] = blockColor * bloom_luma;
        gl_FragData[1] = blockColor;
        gl_FragData[2] = vec4(exposure, 0.0, 0.0, 0.0);
    #else
        blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));
        /* DRAWBUFFERS:16 */
        gl_FragData[0] = blockColor;
        gl_FragData[1] = vec4(exposure, 0.0, 0.0, 0.0);
    #endif
}