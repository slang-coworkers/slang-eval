// A declaration modifier written where the parser expects a type (for example
// `property override float3 X`) ends up on the type expression. Semantic checking
// rejects it with the same E31201 diagnostic that the modifier gets in declaration
// position, rather than with an internal error.

//DIAGNOSTIC_TEST:SIMPLE(diag=CHECK):

interface IFoo
{
    property float3 X { get; }
    property float3 Y { get; }
    property float3 Z { get; }
}

struct Foo : IFoo
{
    property override float3 X { get; }
    //CHECK: ^^^^^^^^ error E31201
    //CHECK: ^^^^^^^^ modifier 'override' is not allowed here

    override property float3 Y { get; }
/*CHECK:
    ^^^^^^^^ error E31201
    ^^^^^^^^ modifier 'override' is not allowed here
*/

    property Z : override float3 { get; }
    //CHECK:     ^^^^^^^^ error E31201
    //CHECK:     ^^^^^^^^ modifier 'override' is not allowed here
}

struct Bar
{
    property public static float P { get { return 0; } }
    //CHECK: ^^^^^^ error E31201
    //CHECK: ^^^^^^ modifier 'public' is not allowed here
    //CHECK:        ^^^^^^ error E31201
    //CHECK:        ^^^^^^ modifier 'static' is not allowed here

    property [ForceInline] float Q { get { return 0; } }
    //CHECK:  ^^^^^^^^^^^ error E31201
    //CHECK:  ^^^^^^^^^^^ modifier 'ForceInline' is not allowed here

    // Modifiers that do apply to a type stay accepted on a property type.
    property no_diff float A { get { return 0; } }
    property row_major float2x3 B { get { return {}; } }
    property unorm float C { get { return 0; } }
}

struct Box<T>
{
    T value;
}

typealias Alias = public float;
//CHECK:          ^^^^^^ error E31201
//CHECK:          ^^^^^^ modifier 'public' is not allowed here

func returnsFloat() -> inline float { return 0; }
//CHECK:               ^^^^^^ error E31201
//CHECK:               ^^^^^^ modifier 'inline' is not allowed here

int castToFloat(int i)
{
    return int((override float)i);
    //CHECK:    ^^^^^^^^ error E31201
    //CHECK:    ^^^^^^^^ modifier 'override' is not allowed here
}

Box<extern float> box;
/*CHECK:
    ^^^^^^ error E31201
    ^^^^^^ modifier 'extern' is not allowed here
*/

float localWithStaticType()
{
    let x : static float = 1;
//CHECK:    ^^^^^^ error E31201
//CHECK:    ^^^^^^ modifier 'static' is not allowed here
    return x;
}
