// GeometryIndex() has a CUDA lowering only in the stages where OptiX defines optixGetSbtGASIndex()
// (intersection, any-hit and closest-hit), so other stages are still diagnosed on CUDA.

//DIAGNOSTIC_TEST:SIMPLE(filecheck=MISS): -target cuda -entry missMain -stage miss
//DIAGNOSTIC_TEST:SIMPLE(filecheck=RAYGEN): -target cuda -entry rayGenMain -stage raygeneration

//MISS: error[E36107]
//MISS: GeometryIndex
//RAYGEN: error[E36107]
//RAYGEN: GeometryIndex

struct Payload
{
    uint geometryIndex;
};

RWStructuredBuffer<uint> outputBuffer;

[shader("miss")]
void missMain(inout Payload payload)
{
    payload.geometryIndex = GeometryIndex();
}

[shader("raygeneration")]
void rayGenMain()
{
    outputBuffer[0] = GeometryIndex();
}
