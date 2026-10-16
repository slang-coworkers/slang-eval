// Forward- and backward-mode derivatives flow through an array-of-matrices conversion that
// changes only the matrix layout.

//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cpu -compute -output-using-type -shaderobj -xslang -matrix-layout-column-major
//TEST(compute, vulkan):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-vk -compute -output-using-type -shaderobj -xslang -matrix-layout-column-major

//TEST_INPUT:ubuffer(data=[0 0], stride=4):out,name=outputBuffer
RWStructuredBuffer<float> outputBuffer;

[Differentiable]
float sumCorners(float4x4 b[2])
{
    return b[0][0][0] + b[1][1][1];
}

[Differentiable]
float scaledSum(float4x4 a0, float4x4 a1)
{
    row_major float4x4 rows[2] = { a0, a1 };
    return sumCorners(rows) * 3.0;
}

[numthreads(1, 1, 1)]
void computeMain()
{
    let forward = fwd_diff(scaledSum)(
        diffPair(float4x4(1.0), float4x4(1.0)),
        diffPair(float4x4(2.0), float4x4(1.0)));
    outputBuffer[0] = forward.d;

    var p0 = diffPair(float4x4(1.0));
    var p1 = diffPair(float4x4(2.0));
    bwd_diff(scaledSum)(p0, p1, 1.0);
    outputBuffer[1] = p0.d[0][0] + p1.d[1][1];
}

// CHECK: 6.0
// CHECK-NEXT: 6.0
