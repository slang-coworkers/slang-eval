// `__isVector<T>()` is true exactly when `T` itself is a vector type.
//
// The peephole fold for the scalar type predicates (`__isFloat`, `__isInt`, ...) unwraps a
// vector or matrix operand to its element type first, so that `__isFloat<float3>()` is true.
// `__isVector` asks about the shape of `T`, not its element type, so it tests `T` before
// any unwrap: `float3` is a vector, while `float`, `float3x3`, an array and a struct are not.

//TEST:COMPARE_COMPUTE(filecheck-buffer=CHECK):-cpu -output-using-type
//TEST:COMPARE_COMPUTE(filecheck-buffer=CHECK):-vk -output-using-type

//TEST_INPUT:ubuffer(data=[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0], stride=4):out,name=outputBuffer
RWStructuredBuffer<int> outputBuffer;

struct HasVectorField
{
    float3 v;
}

interface IHasElement
{
    associatedtype Element;
}

struct VectorElement : IHasElement
{
    typealias Element = float3;
}

struct ScalarElement : IHasElement
{
    typealias Element = float;
}

// The generic functions below are specialized but not inlined, so each predicate is folded
// only after specialization has substituted the generic arguments.
[noinline]
int isVectorAfterSpecialization<T>()
{
    return __isVector<T>() ? 1 : 0;
}

[noinline]
int isVectorOfLength<let N : int>()
{
    return __isVector<vector<float, N>>() ? 1 : 0;
}

[noinline]
int elementIsVector<T : IHasElement>()
{
    return __isVector<T.Element>() ? 1 : 0;
}

[numthreads(1, 1, 1)]
void computeMain()
{
    // CHECK: type: int32_t
    // CHECK-NEXT: 1
    outputBuffer[0] = __isVector<float3>() ? 1 : 0;
    // CHECK-NEXT: 1
    outputBuffer[1] = __isVector<int4>() ? 1 : 0;
    // CHECK-NEXT: 1
    outputBuffer[2] = __isVector<bool2>() ? 1 : 0;
    // CHECK-NEXT: 1
    outputBuffer[3] = __isVector<vector<uint, 1>>() ? 1 : 0;
    // CHECK-NEXT: 1
    outputBuffer[4] = __isVector<vector<float2, 3>>() ? 1 : 0;

    // CHECK-NEXT: 0
    outputBuffer[5] = __isVector<float>() ? 1 : 0;
    // CHECK-NEXT: 0
    outputBuffer[6] = __isVector<float3x3>() ? 1 : 0;
    // CHECK-NEXT: 0
    outputBuffer[7] = __isVector<int[3]>() ? 1 : 0;
    // CHECK-NEXT: 0
    outputBuffer[8] = __isVector<HasVectorField>() ? 1 : 0;

    // CHECK-NEXT: 1
    outputBuffer[9] = isVectorAfterSpecialization<float4>();
    // CHECK-NEXT: 0
    outputBuffer[10] = isVectorAfterSpecialization<int>();
    // CHECK-NEXT: 1
    outputBuffer[11] = isVectorOfLength<4>();
    // CHECK-NEXT: 1
    outputBuffer[12] = elementIsVector<VectorElement>();
    // CHECK-NEXT: 0
    outputBuffer[13] = elementIsVector<ScalarElement>();

    // The scalar predicates keep answering for the element type of a vector or matrix.
    // CHECK-NEXT: 1
    outputBuffer[14] = __isFloat<float3>() ? 1 : 0;
    // CHECK-NEXT: 1
    outputBuffer[15] = __isInt<int2x2>() ? 1 : 0;
    // CHECK-NEXT: 0
    outputBuffer[16] = __isFloat<int4>() ? 1 : 0;
}
