//DIAGNOSTIC_TEST:SIMPLE(diag=CHECK):

// Empty declarations in an interface body are not requirements. A conforming type that misses a
// real requirement is still diagnosed for that requirement by name, and a type that implements
// every real requirement gets no diagnostic. An attribute on an empty declaration is still
// validated where it appears.
interface IFoo
{
    ;
    property float3 X { get; };
//CHECK:            ^ see declaration of 'X'
    void requiredMethod();
//CHECK: ^^^^^^^^^^^^^^ see declaration of 'requiredMethod'
    [ForceInline];
/*CHECK:
     ^^^^^^^^^^^ invalid attribute placement
     ^^^^^^^^^^^ attribute 'ForceInline' is not valid here
*/
}

struct MissingMethod : IFoo
//CHECK:               ^^^^ missing interface member
//CHECK:               ^^^^ type 'MissingMethod' does not provide required interface member 'requiredMethod'
{
    property float3 X { get { return float3(0); } }
}

struct MissingProperty : IFoo
//CHECK:                 ^^^^ missing interface member
//CHECK:                 ^^^^ type 'MissingProperty' does not provide required interface member 'X'
{
    void requiredMethod() {}
}

struct Complete : IFoo
{
    property float3 X { get { return float3(0); } }
    void requiredMethod() {}
}
