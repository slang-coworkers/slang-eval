// `precise` on an entry-point output -- an `out` parameter or a field of a returned
// struct -- must decorate the floating-point arithmetic that computes the output
// with `NoContraction`, just as a `precise` local does, even though the values
// stored into the output are not themselves qualified. Outputs that are not
// `precise` must stay contraction-eligible.

//TEST:SIMPLE(filecheck=OUTPARAM): -target spirv-asm -entry outParamMain -stage vertex
//TEST:SIMPLE(filecheck=FIELD): -target spirv-asm -entry structFieldMain -stage vertex
//TEST:SIMPLE(filecheck=MIXED): -target spirv-asm -entry mixedStructMain -stage vertex
//TEST:SIMPLE(filecheck=WHOLE): -target spirv-asm -entry wholeStructMain -stage vertex
//TEST:SIMPLE(filecheck=SWIZZLE): -target spirv-asm -entry swizzleMain -stage vertex
//TEST:SIMPLE(filecheck=LOCALSWIZZLE): -target spirv-asm -entry localSwizzleMain -stage vertex
//TEST:SIMPLE(filecheck=CLIP): -target spirv-asm -entry clipDistanceMain -stage vertex
//TEST:SIMPLE(filecheck=GLSL): -target glsl -entry structFieldMain -stage vertex

struct VSIn
{
    float3 pos : POSITION;
    float3 scale : SCALE;
    float3 offset : OFFSET;
};

// Only `outPos` is precise: the multiply and add computing `p` must be decorated,
// while the arithmetic feeding the non-precise `outColor` must not be.
void outParamMain(
    VSIn input,
    out precise float4 outPos: SV_Position,
    out float4 outColor: COLOR)
{
    float3 p = input.pos * input.scale + input.offset;
    outPos = float4(p, 1.0);
    outColor = float4(input.scale * input.offset + input.pos, 1.0);
}

//OUTPARAM-COUNT-2: OpDecorate %{{[A-Za-z0-9_]+}} NoContraction
//OUTPARAM-NOT: OpDecorate %{{.*}} NoContraction
//OUTPARAM: %[[MUL:[0-9]+]] = OpFMul %v3float {{.*}}; NoContraction
//OUTPARAM: %p = OpFAdd %v3float %[[MUL]] {{.*}}; NoContraction
//OUTPARAM-NOT: NoContraction
//OUTPARAM: OpFunctionEnd

// A `precise` struct member applies to both a builtin output (`SV_Position`) and a
// user-defined varying (`TEXCOORD0`).
struct VSOut
{
    precise float4 pos : SV_Position;
    precise float4 uv : TEXCOORD0;
};

VSOut structFieldMain(VSIn input, out float4 color: COLOR)
{
    VSOut o;
    float3 p = input.pos * input.scale + input.offset;
    o.pos = float4(p, 1.0);
    float3 t = input.offset * input.pos - input.scale;
    o.uv = float4(t, 0.0);
    color = float4(input.scale * input.pos + input.offset, 1.0);
    return o;
}

//FIELD-COUNT-4: OpDecorate %{{[A-Za-z0-9_]+}} NoContraction
//FIELD-NOT: OpDecorate %{{.*}} NoContraction
//FIELD: %[[PMUL:[0-9]+]] = OpFMul %v3float {{.*}}; NoContraction
//FIELD: %p = OpFAdd %v3float %[[PMUL]] {{.*}}; NoContraction
//FIELD: %[[TMUL:[0-9]+]] = OpFMul %v3float {{.*}}; NoContraction
//FIELD: %t = OpFSub %v3float %[[TMUL]] {{.*}}; NoContraction
//FIELD-NOT: NoContraction
//FIELD: OpFunctionEnd

// On the GLSL target the qualifier is carried to the user varying declaration, so
// glslang applies its own `precise` propagation.
//GLSL: precise layout(location = {{[0-9]+}})
//GLSL-NEXT: out vec4 entryPointParam_structFieldMain_uv

// The struct is read back as a whole before its fields are written to the outputs,
// so the precise walk conservatively reaches the non-precise sibling's arithmetic
// too; that only forgoes contraction there.
struct VSOutMixed
{
    precise float4 pos : SV_Position;
    float4 color : COLOR;
};

VSOutMixed mixedStructMain(VSIn input)
{
    VSOutMixed o;
    float3 p = input.pos * input.scale + input.offset;
    o.pos = float4(p, 1.0);
    o.color = float4(input.scale * input.pos + input.offset, 1.0);
    return o;
}

//MIXED: %[[MUL:[0-9]+]] = OpFMul %v3float {{.*}}; NoContraction
//MIXED: %p = OpFAdd %v3float %[[MUL]] {{.*}}; NoContraction

// `out precise` on a whole struct makes every field of it precise.
struct VSOutPlain
{
    float4 pos : SV_Position;
    float4 color : COLOR;
};

void wholeStructMain(VSIn input, out precise VSOutPlain o)
{
    float3 p = input.pos * input.scale + input.offset;
    o.pos = float4(p, 1.0);
    o.color = float4(input.scale * input.pos + input.offset, 1.0);
}

//WHOLE-COUNT-4: OpDecorate %{{[A-Za-z0-9_]+}} NoContraction
//WHOLE-NOT: OpDecorate %{{.*}} NoContraction

// A swizzled write into a precise output lowers to a `swizzledStore`, not a plain
// store, and must be followed just the same.
void swizzleMain(
    VSIn input,
    out precise float4 outPos: SV_Position,
    out float4 outColor: COLOR)
{
    outPos.xyz = input.pos * input.scale + input.offset;
    outPos.w = 1.0;
    outColor = float4(input.scale * input.offset + input.pos, 1.0);
}

//SWIZZLE-COUNT-2: OpDecorate %{{[A-Za-z0-9_]+}} NoContraction
//SWIZZLE-NOT: OpDecorate %{{.*}} NoContraction
//SWIZZLE: %[[MUL:[0-9]+]] = OpFMul %v3float {{.*}}; NoContraction
//SWIZZLE: = OpFAdd %v3float %[[MUL]] {{.*}}; NoContraction
//SWIZZLE-NOT: NoContraction
//SWIZZLE: OpFunctionEnd

float4 localSwizzleMain(VSIn input) : SV_Position
{
    precise float4 v;
    v.xyz = input.pos * input.scale + input.offset;
    v.w = 1.0;
    return v;
}

//LOCALSWIZZLE: %[[MUL:[0-9]+]] = OpFMul %v3float {{.*}}; NoContraction
//LOCALSWIZZLE: = OpFAdd %v3float %[[MUL]] {{.*}}; NoContraction

// `SV_ClipDistance0` and `SV_ClipDistance1` share one `gl_ClipDistance` array. The
// array is created for the non-precise `clip0` first, so the later `precise` `clip1`
// must still mark it. (The whole shared array is then precise, so `clip0` is decorated
// too.) The position arithmetic is unrelated and stays fast.
void clipDistanceMain(
    VSIn input,
    out float4 pos: SV_Position,
    out float clip0: SV_ClipDistance0,
    out precise float clip1: SV_ClipDistance1)
{
    float3 p = input.pos * input.scale + input.offset;
    pos = float4(p, 1.0);
    clip0 = input.pos.y - input.offset.y;
    float c1 = input.pos.x * input.scale.x + input.offset.x;
    clip1 = c1;
}

//CLIP: %[[PMUL:[0-9]+]] = OpFMul %v3float
//CLIP-NOT: NoContraction
//CLIP: %p = OpFAdd %v3float %[[PMUL]]
//CLIP-NOT: NoContraction
//CLIP: OpFSub %float
//CLIP: %[[CMUL:[0-9]+]] = OpFMul %float {{.*}}; NoContraction
//CLIP: %c1 = OpFAdd %float %[[CMUL]] {{.*}}; NoContraction
