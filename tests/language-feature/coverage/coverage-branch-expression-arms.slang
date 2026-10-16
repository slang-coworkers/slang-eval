// Verifies that `-trace-branch-coverage` gives scalar `?:`, `&&`, and `||`
// a true and a false arm each. `?:` branches on its condition; `&&` and
// `||` branch on their left operand, whose value decides whether the right
// operand is evaluated. In the mixed chain `(a && b) || c`, the inner `&&`
// and the outer `||` are separate sites.

//TEST:SIMPLE(filecheck=CHECK):-target cpp -stage compute -entry computeMain -trace-branch-coverage

RWStructuredBuffer<uint> outputBuffer;

[shader("compute")]
[numthreads(4, 1, 1)]
void computeMain(uint3 tid : SV_DispatchThreadID)
{
    uint t = tid.x;
    uint picked = (t == 3u) ? 10u : 20u;
    bool both = (t != 0u) && (t != 2u);
    bool either = (t == 1u) || (t == 2u);
    bool mixed = ((t != 0u) && (t != 1u)) || (t == 0u);
    outputBuffer[t] = picked + uint(both) + uint(either) + uint(mixed);
}

// Five sites with two arms each: `?:`, `&&`, `||`, and the `&&` and `||`
// of the mixed chain.
//CHECK-DAG: _slang_atomic_add_u64{{.*}}_slang_coverage{{.*int\(0\)}}
//CHECK-DAG: _slang_atomic_add_u64{{.*}}_slang_coverage{{.*int\(1\)}}
//CHECK-DAG: _slang_atomic_add_u64{{.*}}_slang_coverage{{.*int\(2\)}}
//CHECK-DAG: _slang_atomic_add_u64{{.*}}_slang_coverage{{.*int\(3\)}}
//CHECK-DAG: _slang_atomic_add_u64{{.*}}_slang_coverage{{.*int\(4\)}}
//CHECK-DAG: _slang_atomic_add_u64{{.*}}_slang_coverage{{.*int\(5\)}}
//CHECK-DAG: _slang_atomic_add_u64{{.*}}_slang_coverage{{.*int\(6\)}}
//CHECK-DAG: _slang_atomic_add_u64{{.*}}_slang_coverage{{.*int\(7\)}}
//CHECK-DAG: _slang_atomic_add_u64{{.*}}_slang_coverage{{.*int\(8\)}}
//CHECK-DAG: _slang_atomic_add_u64{{.*}}_slang_coverage{{.*int\(9\)}}
//CHECK-NOT: _slang_atomic_add_u64{{.*}}_slang_coverage{{.*int\(10\)}}
