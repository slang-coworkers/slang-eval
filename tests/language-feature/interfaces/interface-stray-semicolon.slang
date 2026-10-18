// A stray `;` inside an interface body parses as an empty declaration. An empty declaration
// declares nothing, so it must not become an interface requirement that conforming types have to
// satisfy.

//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cpu -compute -output-using-type
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-vk -compute -output-using-type

interface IFoo
{
    property float3 X { get; };
}

struct Foo : IFoo
{
    property float3 X { get { return float3(1, 2, 3); } }
}

interface IEmpty
{
    ;
}

struct Empty : IEmpty {}

interface IBase
{
    ;
    int base();
    ;
}

interface IDerived : IBase
{
    ;;
    static int twice(int v);
    int withDefault() { return 7; };
}

struct Derived : IDerived
{
    int base() { return 10; }
    static int twice(int v) { return v * 2; }
}

interface IGeneric<T>
{
    ;
    T get();
    __generic<U> ;
    __generic<U> U convert(U value);
    ;
}

struct Generic : IGeneric<int>
{
    int get() { return 100; }
    U convert<U>(U value) { return value; }
}

float readX<T : IFoo>(T value) { return value.X.z; }

int useEmpty<T : IEmpty>(T value) { return 1000; }

int useDerived<T : IDerived>(T value) { return value.base() + T.twice(3) + value.withDefault(); }

int useGeneric<T : IGeneric<int>>(T value) { return value.get() + value.convert(5); }

//TEST_INPUT: set outputBuffer = out ubuffer(data=[0 0 0 0 0], stride=4)
RWStructuredBuffer<float> outputBuffer;

[numthreads(1, 1, 1)]
void computeMain()
{
    Foo foo;
    IFoo iFoo = foo;
    outputBuffer[0] = iFoo.X.y;
    outputBuffer[1] = readX(foo);

    Derived derived;
    outputBuffer[2] = useDerived(derived);

    Generic generic;
    outputBuffer[3] = useGeneric(generic);

    Empty empty;
    outputBuffer[4] = useEmpty(empty);
}

// CHECK: 2.0
// CHECK-NEXT: 3.0
// CHECK-NEXT: 23.0
// CHECK-NEXT: 105.0
// CHECK-NEXT: 1000.0
