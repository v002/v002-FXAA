/*
FXAA fragment shader by Timothy Lottes
http://timothylottes.blogspot.com/
GLSL version by Geeks3D
http://www.geeks3d.com/
modified and adapted to BGE by Martins Upitis
http://devlog-martinsh.blogspot.com/
QC / Texture2DRect conversion by vade
http://v002.info
*/

#version 120

uniform sampler2DRect bgl_RenderedTexture; //redered scene texture
uniform float bgl_RenderedTextureWidth; //texture width
uniform float bgl_RenderedTextureHeight; //texture height

float width = bgl_RenderedTextureWidth;
float height = bgl_RenderedTextureHeight;


const vec3 luma = vec3(0.299, 0.587, 0.114);
const float FXAA_SUBPIX_SHIFT = 1.0/4.0;

vec2 rcpFrame = vec2(1.0/width, 1.0/height);

vec4 posPos = vec4(gl_TexCoord[0].st,gl_TexCoord[0].st -((0.5 + FXAA_SUBPIX_SHIFT)));


vec4 FxaaPixelShader(
  vec4 posPos, // Output of FxaaVertexShader interpolated across screen.
  sampler2DRect tex, // Input texture.
  vec2 rcpFrame) // Constant {1.0/frameWidth, 1.0/frameHeight}.
{
/*---------------------------------------------------------*/
    #define FXAA_REDUCE_MIN   (1.0/128.0)
    #define FXAA_REDUCE_MUL   (1.0/8.0)
    #define FXAA_SPAN_MAX     8.0
/*---------------------------------------------------------*/
    vec3 rgbNW = texture2DRect(tex, posPos.zw).xyz;
    vec3 rgbNE = texture2DRect(tex, posPos.zw + vec2(1.0,0.0)).xyz;
    vec3 rgbSW = texture2DRect(tex, posPos.zw + vec2(0.0,1.0)).xyz;
    vec3 rgbSE = texture2DRect(tex, posPos.zw + vec2(1.0,1.0)).xyz;
    vec3 rgbM  = texture2DRect(tex, posPos.xy).xyz;
/*---------------------------------------------------------*/
    float lumaNW = dot(rgbNW, luma);
    float lumaNE = dot(rgbNE, luma);
    float lumaSW = dot(rgbSW, luma);
    float lumaSE = dot(rgbSE, luma);
    float lumaM  = dot(rgbM,  luma);
/*---------------------------------------------------------*/
    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
/*---------------------------------------------------------*/
    vec2 dir;
    dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
    dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));
/*---------------------------------------------------------*/
    float dirReduce = max(
        (lumaNW + lumaNE + lumaSW + lumaSE) * (0.25 * FXAA_REDUCE_MUL),
        FXAA_REDUCE_MIN);
    float rcpDirMin = 1.0/(min(abs(dir.x), abs(dir.y)) + dirReduce);
    dir = min(vec2( FXAA_SPAN_MAX,  FXAA_SPAN_MAX),
          max(vec2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX),
          dir * rcpDirMin)); //* rcpFrame.xy;
/*--------------------------------------------------------*/
    vec4 rgbA = (1.0/2.0) * (
        texture2DRect(tex, posPos.xy + dir * (1.0/3.0 - 0.5)) +
        texture2DRect(tex, posPos.xy + dir * (2.0/3.0 - 0.5)));
    vec4 rgbB = rgbA * (1.0/2.0) + (1.0/4.0) * (
        texture2DRect(tex, posPos.xy + dir * (0.0/3.0 - 0.5)) +
        texture2DRect(tex, posPos.xy + dir * (3.0/3.0 - 0.5)));
    float lumaB = dot(rgbB, vec4(luma, 0.0));
    if((lumaB < lumaMin) || (lumaB > lumaMax)) return rgbA;
    return rgbB; }

vec4 PostFX(sampler2DRect tex, vec2 uv)
{
    vec4 c = vec4(0.0);
    vec2 rcpFrame = vec2(1.0/width, 1.0/height);
    c = FxaaPixelShader(posPos, tex, rcpFrame);
    //c.rgb = 1.0 - texture2D(bgl_RenderedTexture, posPos.xy).rgb;
    //c.a = 1.0;
    return c;
}

void main()
{
    vec2 uv = gl_TexCoord[0].st;
    gl_FragColor = PostFX(bgl_RenderedTexture, uv);
}