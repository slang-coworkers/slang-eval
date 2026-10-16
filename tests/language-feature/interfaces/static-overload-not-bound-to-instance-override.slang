// `IHit` declares a defaulted instance method `value()` and a defaulted static
// overload `value(Packed)`. `Hit` overrides only the instance method. When the
// compiler checks `Hit : IHit`, the static requirement must be satisfied by the
// inherited default body, which reconstructs a `Hit` and calls its `value()`,
// not by binding the `Packed` argument as the receiver of `Hit::value()`.
//
// A non-static method can still satisfy a static requirement whose first
// parameter is `This` (`scaled` below), so that adaptation is also checked.

//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cpu -compute -shaderobj -output-using-type
//TEST(compute, vulkan):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-vk -compute -shaderobj -output-using-type
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cuda -compute -shaderobj -output-using-type
//TEST:SIMPLE(filecheck=SPV):-target spirv-asm -stage compute -entry computeMain -conformance "Hit:IHit=0"
//TEST:SIMPLE(filecheck=HLSL):-target hlsl -stage compute -entry computeMain -conformance "Hit:IHit=0"

// `pad` gives `Packed` the same 16-byte layout on every target, so one buffer
// initializer feeds the CPU, Vulkan and CUDA runs.
struct Packed
{
    uint instance;
    uint pad;
    float2 uv;
}

interface IHit
{
    static This unpack(Packed p);

    float value() { return 0.0; }

    static float value(Packed p) { return This.unpack(p).value(); }

    static float scaled(This self, float k);
}

struct Hit : IHit
{
    uint instance;
    float2 uv;

    static This unpack(Packed p) { return { p.instance, p.uv }; }

    override float value() { return float(instance) + uv.x + uv.y; }

    float scaled(float k) { return value() * k; }
}

float viaGeneric<T : IHit>(Packed p)
{
    return T.value(p);
}

float scaledViaGeneric<T : IHit>(Packed p, float k)
{
    return T.scaled(T.unpack(p), k);
}

// SPV: OpEntryPoint
// HLSL-NOT: Hit_value_{{[0-9]+}}(p{{(_[0-9]+)?}})
// HLSL: void computeMain

//TEST_INPUT: set inputBuffer = ubuffer(data=[1 0 0.5 0.25 2 0 0.5 0.25 3 0 0.5 0.25 4 0 0.5 0.25], stride=16)
StructuredBuffer<Packed> inputBuffer;

//TEST_INPUT: set outputBuffer = out ubuffer(data=[0 0 0 0 0 0 0 0 0 0 0 0], stride=4)
RWStructuredBuffer<float> outputBuffer;

//TEST_INPUT: type_conformance Hit:IHit = 0

[numthreads(4, 1, 1)]
void computeMain(uint3 tid: SV_DispatchThreadID)
{
    let dynamicHit = createDynamicObject<IHit>(0u, 0u);
    outputBuffer[tid.x * 3 + 0] = dynamicHit.value(inputBuffer[tid.x]);
    outputBuffer[tid.x * 3 + 1] = viaGeneric<Hit>(inputBuffer[tid.x]);
    outputBuffer[tid.x * 3 + 2] = scaledViaGeneric<Hit>(inputBuffer[tid.x], 2.0);
}

// CHECK: 1.75
// CHECK-NEXT: 1.75
// CHECK-NEXT: 3.5
// CHECK-NEXT: 2.75
// CHECK-NEXT: 2.75
// CHECK-NEXT: 5.5
// CHECK-NEXT: 3.75
// CHECK-NEXT: 3.75
// CHECK-NEXT: 7.5
// CHECK-NEXT: 4.75
// CHECK-NEXT: 4.75
// CHECK-NEXT: 9.5
