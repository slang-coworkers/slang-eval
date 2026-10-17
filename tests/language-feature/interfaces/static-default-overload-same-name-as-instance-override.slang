// An interface declares an instance method `value()` with a default body and a
// static overload `value(Packed)` with a default body. A conforming type that
// overrides only the instance `value()` must still get the interface's default
// for the static `value(Packed)`, through both generic and dynamic dispatch.
//
// The second interface checks that a static requirement whose first parameter
// is `This` can still be satisfied by an instance method of the same name, with
// that parameter bound as the receiver.

//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cpu -compute -shaderobj -output-using-type
//TEST(compute, vulkan):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-vk -compute -shaderobj -output-using-type
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cuda -compute -shaderobj -output-using-type
//TEST:SIMPLE(filecheck=SPV):-target spirv-asm -stage compute -entry computeMain -conformance Hit:IHit=0
//TEST:SIMPLE(filecheck=HLSL):-target hlsl -stage compute -entry computeMain -conformance Hit:IHit=0

// `uv` comes first so that `Packed` has the same layout on every target.
struct Packed
{
    float2 uv;
    uint instance;
}

interface IHit
{
    static This unpack(Packed p);
    float value() { return 0.0; }
    static float value(Packed p) { return This.unpack(p).value(); }
}

struct Hit : IHit
{
    uint instance;
    float2 uv;
    static This unpack(Packed p) { return { p.instance, p.uv }; }
    override float value() { return float(instance) + uv.x + uv.y; }
}

interface IScale
{
    static float scaled(This v, float k);
}

struct Box : IScale
{
    float x;
    float scaled(float k) { return x * k; }
}

float valueViaGeneric<T : IHit>(Packed p)
{
    return T.value(p);
}

float scaledViaGeneric<T : IScale>(T v, float k)
{
    return T.scaled(v, k);
}

// SPV: OpEntryPoint

// The static `value(Packed)` witness is the interface default, which unpacks a
// `Hit` and then calls the instance override on it. Both the generic and the
// dynamic call sites use that default.
// HLSL-NOT: Hit_value_0(p_{{[0-9]+}})
// HLSL: float IHit_valuex24defaultImpl_0(Packed_0 [[P:p_[0-9]+]])
// HLSL: return Hit_value_0(Hit_unpack_0([[P]]));
// HLSL: Box_scaled_0(
// HLSL: float valueViaGeneric_0(
// HLSL-NEXT: {
// HLSL-NEXT: return IHit_valuex24defaultImpl_0(
// HLSL: = IHit_valuex24defaultImpl_0(inputBuffer_0.Load(

//TEST_INPUT: type_conformance Hit:IHit = 0

//TEST_INPUT:ubuffer(data=[2.0 3.0 1 0], stride=16):name=inputBuffer
StructuredBuffer<Packed> inputBuffer;

//TEST_INPUT:ubuffer(data=[0 0 0 0], stride=4):out,name=outputBuffer
RWStructuredBuffer<float> outputBuffer;

[numthreads(1, 1, 1)]
void computeMain()
{
    Packed p = inputBuffer[0];

    outputBuffer[0] = valueViaGeneric<Hit>(p);
    // CHECK: 6.0

    let hit = createDynamicObject<IHit>(0u, 0u);
    outputBuffer[1] = hit.value(inputBuffer[0]);
    // CHECK-NEXT: 6.0

    outputBuffer[2] = Hit.unpack(p).value();
    // CHECK-NEXT: 6.0

    Box b = { 3.0 };
    outputBuffer[3] = scaledViaGeneric(b, 2.0);
    // CHECK-NEXT: 6.0
}
