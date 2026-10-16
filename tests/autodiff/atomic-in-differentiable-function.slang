// An atomic operation inside a differentiable function is a non-differentiable side effect, like a
// store to a buffer: it must not block differentiation and must not change the derivative.

//TEST(compute):COMPARE_COMPUTE(filecheck-buffer=CHECK):-cpu -output-using-type
//TEST(compute, vulkan):COMPARE_COMPUTE(filecheck-buffer=CHECK):-vk -output-using-type
//TEST(compute):COMPARE_COMPUTE(filecheck-buffer=CHECK):-cuda -output-using-type

//TEST_INPUT: set outputBuffer = out ubuffer(data=[0 0 0 0 0 0 0 0 0 0], stride=4)
RWStructuredBuffer<float> outputBuffer;

//TEST_INPUT: set counters = ubuffer(data=[0 0 0 0], stride=4)
RWStructuredBuffer<Atomic<uint>> counters;

// `Atomic<T>.load()` is not available on the CPU target, so we read a counter with `add(0)`.
uint readCounter(uint index)
{
    return counters[index].add(0u);
}

[Differentiable]
float square(float x)
{
    counters[0].add(1u);
    return x * x;
}

// The backward pass needs the scale factor, which depends on the value the atomic returns. The
// first run sees 0 and uses 2; a second run of the atomic would see 1 and use 5.
[Differentiable]
float scaledSquare(float x)
{
    uint previous = counters[1].add(1u);
    float scale = previous == 0u ? 2.0f : 5.0f;
    return scale * x * x;
}

[Differentiable]
float cube(float x)
{
    float result = 1.0f;
    [MaxIters(3)]
    for (int i = 0; i < 3; i++)
    {
        counters[2].add(1u);
        result = result * x;
    }
    return result;
}

// The loop's control flow depends on the values the atomic returns, so the backward pass replays
// the primal decisions: iterations 0 and 2 multiply, which makes the result x^3.
[Differentiable]
float branchOnAtomicInLoop(float x)
{
    float result = x;
    [MaxIters(4)]
    for (int i = 0; i < 4; i++)
    {
        uint original = counters[3].add(1u);
        if (original % 2u == 0u)
            result = result * x;
    }
    return result;
}

[shader("compute")]
[numthreads(1, 1, 1)]
void computeMain()
{
    outputBuffer[0] = fwd_diff(square)(diffPair(3.0f, 1.0f)).d;
    outputBuffer[1] = float(readCounter(0));

    var dpSquare = diffPair(3.0f, 0.0f);
    bwd_diff(square)(dpSquare, 1.0f);
    outputBuffer[2] = dpSquare.d;

    var dpScaled = diffPair(3.0f, 0.0f);
    bwd_diff(scaledSquare)(dpScaled, 1.0f);
    outputBuffer[3] = dpScaled.d;
    outputBuffer[4] = float(readCounter(1));

    outputBuffer[5] = fwd_diff(cube)(diffPair(2.0f, 1.0f)).d;
    outputBuffer[6] = float(readCounter(2));

    var dpCube = diffPair(2.0f, 0.0f);
    bwd_diff(cube)(dpCube, 1.0f);
    outputBuffer[7] = dpCube.d;

    var dpBranch = diffPair(2.0f, 0.0f);
    bwd_diff(branchOnAtomicInLoop)(dpBranch, 1.0f);
    outputBuffer[8] = dpBranch.d;
    outputBuffer[9] = float(readCounter(3));
}

// fwd_diff(square) at 3: derivative 6, and the atomic ran once.
// CHECK: 6.0
// CHECK-NEXT: 1.0
// bwd_diff(square) at 3.
// CHECK-NEXT: 6.0
// bwd_diff(scaledSquare) at 3: the derivative of 2x^2 is 12, so the backward pass used the value
// from the single run of the atomic, and the atomic was not run again.
// CHECK-NEXT: 12.0
// CHECK-NEXT: 1.0
// fwd_diff(cube) at 2: derivative 12, and the loop ran the atomic three times.
// CHECK-NEXT: 12.0
// CHECK-NEXT: 3.0
// bwd_diff(cube) at 2.
// CHECK-NEXT: 12.0
// bwd_diff(branchOnAtomicInLoop) at 2: derivative of x^3 is 12, and the loop ran the atomic four
// times.
// CHECK-NEXT: 12.0
// CHECK-NEXT: 4.0
