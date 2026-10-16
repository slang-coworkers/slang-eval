// Atomic operations of every kind (device buffer, `groupshared` and texture destinations,
// with and without the original value, compare-exchange, `Atomic<T>` members, and inside a
// loop) are non-differentiable side effects, so a differentiable function that contains them
// compiles under both `fwd_diff` and `bwd_diff` on every target. Most of these forms are not
// available on the CPU target (for example `Interlocked*` with an original-value out-parameter),
// so `atomic-in-differentiable-function.slang` covers it with `Atomic<T>`.

//TEST:SIMPLE(filecheck=SPIRV):-target spirv-asm -stage compute -entry computeMain
//TEST:SIMPLE(filecheck=HLSL):-target hlsl -stage compute -entry computeMain
//TEST:SIMPLE(filecheck=GLSL):-target glsl -stage compute -entry computeMain
//TEST:SIMPLE(filecheck=METAL):-target metal -stage compute -entry computeMain
//TEST:SIMPLE(filecheck=CUDA):-target cuda -stage compute -entry computeMain

RWStructuredBuffer<float> outputBuffer;
RWStructuredBuffer<uint> counters;
RWTexture2D<uint> counterTexture;
groupshared uint sharedCounter;
RWStructuredBuffer<Atomic<uint>> atomicCounters;

[Differentiable]
float addWithoutOriginal(float x)
{
    InterlockedAdd(counters[0], 1u);
    return x * x;
}

[Differentiable]
float addWithOriginal(float x)
{
    uint original;
    InterlockedAdd(counters[1], 1u, original);
    return original == 0u ? x * x : x;
}

[Differentiable]
float compareExchange(float x)
{
    uint original;
    InterlockedCompareExchange(counters[2], 0u, 1u, original);
    return x * float(original + 1u);
}

[Differentiable]
float groupsharedAndTexture(float x)
{
    InterlockedAdd(sharedCounter, 1u);
    InterlockedMax(counterTexture[uint2(0, 0)], 7u);
    return x * x * x;
}

[Differentiable]
float atomicMembers(float x)
{
    atomicCounters[0].increment();
    uint previous = atomicCounters[1].exchange(3u);
    atomicCounters[2].compareExchange(0u, previous);
    atomicCounters[3].store(atomicCounters[3].load() + 1u);
    return x * x;
}

[Differentiable]
float atomicInLoop(float x)
{
    float result = x;
    [MaxIters(4)]
    for (int i = 0; i < 4; i++)
    {
        uint original;
        InterlockedAdd(counters[3], 1u, original);
        if (original % 2u == 0u)
            result = result * x;
    }
    return result;
}

[shader("compute")]
[numthreads(1, 1, 1)]
void computeMain()
{
    outputBuffer[0] = fwd_diff(addWithoutOriginal)(diffPair(outputBuffer[0], 1.0f)).d;
    outputBuffer[1] = fwd_diff(addWithOriginal)(diffPair(outputBuffer[1], 1.0f)).d;
    outputBuffer[2] = fwd_diff(compareExchange)(diffPair(outputBuffer[2], 1.0f)).d;
    outputBuffer[3] = fwd_diff(groupsharedAndTexture)(diffPair(outputBuffer[3], 1.0f)).d;
    outputBuffer[4] = fwd_diff(atomicInLoop)(diffPair(outputBuffer[4], 1.0f)).d;
    outputBuffer[5] = fwd_diff(atomicMembers)(diffPair(outputBuffer[5], 1.0f)).d;

    var dp0 = diffPair(outputBuffer[6], 0.0f);
    bwd_diff(addWithoutOriginal)(dp0, 1.0f);
    var dp1 = diffPair(outputBuffer[7], 0.0f);
    bwd_diff(addWithOriginal)(dp1, 1.0f);
    var dp2 = diffPair(outputBuffer[8], 0.0f);
    bwd_diff(compareExchange)(dp2, 1.0f);
    var dp3 = diffPair(outputBuffer[9], 0.0f);
    bwd_diff(groupsharedAndTexture)(dp3, 1.0f);
    var dp4 = diffPair(outputBuffer[10], 0.0f);
    bwd_diff(atomicInLoop)(dp4, 1.0f);
    var dp5 = diffPair(outputBuffer[11], 0.0f);
    bwd_diff(atomicMembers)(dp5, 1.0f);
    outputBuffer[12] = dp0.d + dp1.d + dp2.d + dp3.d + dp4.d + dp5.d;
}

// SPIRV-DAG: OpAtomicIAdd
// SPIRV-DAG: OpAtomicCompareExchange
// SPIRV-DAG: OpAtomicUMax
// SPIRV-DAG: OpAtomicIIncrement
// SPIRV-DAG: OpAtomicExchange
// SPIRV-DAG: OpAtomicLoad
// SPIRV-DAG: OpAtomicStore
// HLSL-DAG: InterlockedAdd
// HLSL-DAG: InterlockedCompareExchange
// HLSL-DAG: InterlockedMax
// HLSL-DAG: InterlockedExchange
// GLSL-DAG: atomicAdd
// GLSL-DAG: atomicCompSwap
// GLSL-DAG: imageAtomicMax
// GLSL-DAG: atomicExchange
// METAL-DAG: atomic_fetch_add_explicit
// METAL-DAG: atomic_compare_exchange_weak_explicit
// METAL-DAG: atomic_fetch_max
// METAL-DAG: atomic_exchange_explicit
// METAL-DAG: atomic_load_explicit
// METAL-DAG: atomic_store_explicit
// CUDA-DAG: atomicAdd
// CUDA-DAG: atomicCAS
// CUDA-DAG: atomicMax
// CUDA-DAG: atomicExch
