uniform float dayMoment;
uniform float dayMixer;
uniform float nightMixer;
uniform int moonPhase;

#ifdef UNKNOWN_DIM
    uniform vec3 fogColor;
    uniform vec3 skyColor;
#endif

#define NIGHT_BRIGHT_PHASE (NIGHT_BRIGHT + (NIGHT_BRIGHT * (abs(4.0 - moonPhase) * 0.25)))

#define OMNI_TINT 0.45
#define LIGHT_SUNSET_COLOR vec3(1.0, 0.55, 0.2)
#define LIGHT_DAY_COLOR vec3(0.95, 0.95, 0.9)
#define LIGHT_NIGHT_COLOR vec3(0.03, 0.04, 0.07) * NIGHT_BRIGHT_PHASE

#define ZENITH_SUNSET_COLOR vec3(0.35, 0.25, 0.55)
#define ZENITH_DAY_COLOR vec3(0.1, 0.4, 0.95)
#define ZENITH_NIGHT_COLOR vec3(0.01, 0.015, 0.03) * NIGHT_BRIGHT_PHASE

#define HORIZON_SUNSET_COLOR vec3(1.0, 0.65, 0.5)
#define HORIZON_DAY_COLOR vec3(0.65, 0.9, 1.1)
#define HORIZON_NIGHT_COLOR vec3(0.02, 0.03, 0.05) * NIGHT_BRIGHT_PHASE

#define WATER_COLOR vec3(0.15, 0.35, 0.6)

#define NV_COLOR vec3(NV_COLOR_R, NV_COLOR_G, NV_COLOR_B)

#if BLOCKLIGHT_TEMP == 0
    #define CANDLE_BASELIGHT vec3(0.29975, 0.15392353, 0.0799)
#elif BLOCKLIGHT_TEMP == 1
    #define CANDLE_BASELIGHT vec3(0.27475, 0.17392353, 0.0899)
#elif BLOCKLIGHT_TEMP == 2
    #define CANDLE_BASELIGHT vec3(0.24975, 0.19392353, 0.0999)
#elif BLOCKLIGHT_TEMP == 3
    #define CANDLE_BASELIGHT vec3(0.22, 0.19, 0.14)
#else
    #define CANDLE_BASELIGHT vec3(0.19, 0.19, 0.19)
#endif

#include "/lib/day_blend.glsl"

#if VOL_LIGHT == 1 || (VOL_LIGHT == 2 && defined SHADOW_CASTING) || defined UNKNOWN_DIM
    #define FOG_DENSITY 3.0
#else
    #define FOG_DAY 3.0
    #define FOG_SUNSET 2.0
    #define FOG_NIGHT 3.0
#endif

#include "/lib/color_conversion.glsl"