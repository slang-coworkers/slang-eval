//DIAGNOSTIC_TEST:SIMPLE(diag=CHECK): -target spirv

// A static requirement whose first parameter is not `This` cannot be satisfied
// by an instance method of the same name, because the argument cannot be the
// method's receiver. Without a default implementation the requirement is
// reported as unsatisfied, rather than satisfied by a call that passes the
// first argument as `this`. That holds even when the argument type converts
// implicitly to the conforming type, as `int` does to `float` below.

struct Packed
{
    float2 uv;
    uint instance;
}

interface IHit
{
    float value();
    static float value(Packed p);
//CHECK:         ^^^^^ see interface requirement declaration of 'value'
}

struct Hit : IHit
{
    uint instance;
    float2 uv;
    float value() { return float(instance) + uv.x + uv.y; }
//CHECK:  ^^^^^ interface requirement mismatch
//CHECK:  ^^^^^ member 'value' does not match interface requirement.
}

interface IFromInt
{
    static float scaled(int v);
//CHECK:         ^^^^^^ see interface requirement declaration of 'scaled'
}

extension float : IFromInt
{
    float scaled() { return this * 2.0; }
//CHECK:  ^^^^^^ interface requirement mismatch
//CHECK:  ^^^^^^ member 'scaled' does not match interface requirement.
}

float valueViaGeneric<T : IHit>(Packed p)
{
    return T.value(p);
}

StructuredBuffer<Packed> inputBuffer;
RWStructuredBuffer<float> outputBuffer;

[numthreads(1, 1, 1)]
void computeMain()
{
    outputBuffer[0] = valueViaGeneric<Hit>(inputBuffer[0]);
    outputBuffer[1] = float.scaled(3);
}
