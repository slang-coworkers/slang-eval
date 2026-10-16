// Verifies that `&&` and `||` get no branch coverage counters under
// `-disable-short-circuit`: both operands are always evaluated, so there is
// no branch to report. The `if` that consumes them is still a site.

//TEST:SIMPLE(filecheck=CHECK):-target cpp -stage compute -entry computeMain -trace-branch-coverage -disable-short-circuit

RWStructuredBuffer<uint> outputBuffer;

[shader("compute")]
[numthreads(1, 1, 1)]
void computeMain(uint3 tid : SV_DispatchThreadID)
{
    bool both = (tid.x != 0u) && (tid.y != 0u);
    bool either = (tid.x == 1u) || (tid.y == 1u);
    uint value = 0u;
    if (both || either)
        value = 1u;
    outputBuffer[0] = value;
}

// Only the `if` contributes branch counters.
//CHECK-DAG: _slang_atomic_add_u64{{.*}}_slang_coverage{{.*int\(0\)}}
//CHECK-DAG: _slang_atomic_add_u64{{.*}}_slang_coverage{{.*int\(1\)}}
//CHECK-NOT: _slang_atomic_add_u64{{.*}}_slang_coverage{{.*int\(2\)}}
