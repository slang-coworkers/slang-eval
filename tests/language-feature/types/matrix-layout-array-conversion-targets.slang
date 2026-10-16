// A `row_major` cbuffer array of matrices passed to a plain-array parameter compiles for every
// target, with a row-major or a column-major default.

//TEST:SIMPLE(filecheck=SPIRV):-target spirv-asm -entry main -stage vertex -matrix-layout-row-major
//TEST:SIMPLE(filecheck=SPIRV):-target spirv-asm -entry main -stage vertex -matrix-layout-column-major
//TEST:SIMPLE(filecheck=HLSL-ROW):-target hlsl -entry main -stage vertex -matrix-layout-row-major
//TEST:SIMPLE(filecheck=HLSL-COLUMN):-target hlsl -entry main -stage vertex -matrix-layout-column-major
//TEST:SIMPLE(filecheck=GLSL):-target glsl -entry main -stage vertex -matrix-layout-row-major
//TEST:SIMPLE(filecheck=GLSL):-target glsl -entry main -stage vertex -matrix-layout-column-major
//TEST:SIMPLE(filecheck=METAL):-target metal -entry main -stage vertex -matrix-layout-row-major
//TEST:SIMPLE(filecheck=METAL):-target metal -entry main -stage vertex -matrix-layout-column-major

cbuffer Skin
{
    row_major float4x4 bones[4];
}

float3 skin(float4x4 b[4], uint i, float3 p)
{
    return mul(float4(p, 1), b[i]).xyz;
}

// SPIRV: OpEntryPoint Vertex
// GLSL: vec3 skin_0(
// METAL: float3 skin_0(

// With a row-major default the conversion is an identity: no array copy is built, so the
// specialized `skin` reads the cbuffer directly instead of taking the array as a parameter.
// HLSL-ROW: float3 skin_0(uint
// With a column-major default each element converts, and the converted array is passed in.
// HLSL-COLUMN: float3 skin_0(float4x4 {{.*}}[int(4)]

[shader("vertex")]
float4 main(float3 p : POSITION, uint i : BLENDINDICES) : SV_Position
{
    return float4(skin(bones, i, p), 1);
}
