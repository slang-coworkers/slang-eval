// An array of matrices whose length is a specialization constant converts to a plain array of the
// same length. Its length is not known at compile time, so the conversion is a loop.

//TEST:SIMPLE(filecheck=SPIRV):-target spirv-asm -entry computeMain -stage compute
//TEST:SIMPLE(filecheck=HLSL):-target hlsl -entry computeMain -stage compute

[SpecializationConstant]
const int kBoneCount = 2;

RWStructuredBuffer<float> outputBuffer;

float pick(float4x4 b[kBoneCount], int i)
{
    return b[i][0][0];
}

// SPIRV: OpDecorate {{.*}} SpecId
// SPIRV: OpLoopMerge
// HLSL: void convertArrayMatrixLayout_0(row_major float4x4 {{.*}}[globalParams_0.kBoneCount_0]

[numthreads(1, 1, 1)]
void computeMain()
{
    row_major float4x4 bones[kBoneCount];
    bones[0] = float4x4(1.0);
    bones[1] = float4x4(2.0);
    outputBuffer[0] = pick(bones, 1);
}
