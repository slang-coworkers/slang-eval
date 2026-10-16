// The counting coverage modes instrument every function, including differentiable ones, with
// atomic counter increments. Those increments are non-differentiable side effects, so a shader
// that differentiates a function compiles with each counting mode enabled.

//TEST:SIMPLE(filecheck=SPIRV):-target spirv-asm -stage compute -entry computeMain -trace-coverage
//TEST:SIMPLE(filecheck=SPIRV):-target spirv-asm -stage compute -entry computeMain -trace-function-coverage
//TEST:SIMPLE(filecheck=SPIRV):-target spirv-asm -stage compute -entry computeMain -trace-branch-coverage
//TEST:SIMPLE(filecheck=CPP):-target cpp -stage compute -entry computeMain -trace-coverage -trace-function-coverage -trace-branch-coverage

RWStructuredBuffer<float> outputBuffer;

[Differentiable]
float f(float x)
{
    float result = x * x;
    if (x > 0.0f)
        result = result * x;
    return result;
}

[shader("compute")]
[numthreads(1, 1, 1)]
void computeMain()
{
    outputBuffer[0] = fwd_diff(f)(diffPair(outputBuffer[0], 1.0f)).d;

    var dp = diffPair(outputBuffer[1], 0.0f);
    bwd_diff(f)(dp, 1.0f);
    outputBuffer[1] = dp.d;
}

// SPIRV: OpEntryPoint GLCompute %computeMain "main" {{.*}}%__slang_coverage
// SPIRV: OpAtomicIAdd
// CPP: _slang_atomic_add_u64({{.*}}_slang_coverage
