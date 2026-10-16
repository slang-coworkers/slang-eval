// An array of matrices converts implicitly to an array of the same matrix type with a different
// matrix layout, as a single matrix already does. The conversion copies element-wise, so each
// matrix keeps its logical value.

//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cpu -compute -output-using-type -shaderobj -xslang -matrix-layout-row-major
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cpu -compute -output-using-type -shaderobj -xslang -matrix-layout-column-major
//TEST(compute, vulkan):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-vk -compute -output-using-type -shaderobj -xslang -matrix-layout-row-major
//TEST(compute, vulkan):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-vk -compute -output-using-type -shaderobj -xslang -matrix-layout-column-major
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cuda -compute -output-using-type -shaderobj -xslang -matrix-layout-row-major
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cuda -compute -output-using-type -shaderobj -xslang -matrix-layout-column-major

struct Bones
{
    row_major float4x4 m[2];
}

// Element [i][r][c] of each buffer below holds its own float offset in the buffer data.
//TEST_INPUT:cbuffer(data=[0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0 21.0 22.0 23.0 24.0 25.0 26.0 27.0 28.0 29.0 30.0 31.0 32.0 33.0 34.0 35.0 36.0 37.0 38.0 39.0 40.0 41.0 42.0 43.0 44.0 45.0 46.0 47.0 48.0 49.0 50.0 51.0 52.0 53.0 54.0 55.0 56.0 57.0 58.0 59.0 60.0 61.0 62.0 63.0 64.0 65.0 66.0 67.0 68.0 69.0 70.0 71.0 72.0 73.0 74.0 75.0 76.0 77.0 78.0 79.0 80.0 81.0 82.0 83.0 84.0 85.0 86.0 87.0 88.0 89.0 90.0 91.0 92.0 93.0 94.0 95.0]):name=Skin
cbuffer Skin
{
    row_major float4x4 rowBones[2];
    column_major float4x4 columnBones[2];
    Bones nested;
}

//TEST_INPUT:ubuffer(data=[100.0 101.0 102.0 103.0 104.0 105.0 106.0 107.0 108.0 109.0 110.0 111.0 112.0 113.0 114.0 115.0 116.0 117.0 118.0 119.0 120.0 121.0 122.0 123.0 124.0 125.0 126.0 127.0 128.0 129.0 130.0 131.0], stride=4):name=boneBuffer
StructuredBuffer<Bones> boneBuffer;

//TEST_INPUT:ubuffer(data=[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0], stride=4):out,name=outputBuffer
RWStructuredBuffer<float> outputBuffer;

float pick(float4x4 b[2], int i, int r, int c)
{
    return b[i][r][c];
}

float pickSized<let N : int>(float4x4 b[N], int i, int r, int c)
{
    return b[i][r][c];
}

float pickUnsized(float4x4 b[], int i, int r, int c)
{
    return b[i][r][c];
}

float pickNested(float4x4 b[2][2], int i, int j, int r, int c)
{
    return b[i][j][r][c];
}

func pickRowMajor(b: row_major float4x4[2], i: int, r: int, c: int) -> float
{
    return b[i][r][c];
}

// An array longer than the inline-conversion limit converts with a loop.
float sumDiagonals(float4x4 b[40])
{
    float sum = 0;
    for (int i = 0; i < 40; i++)
        sum += b[i][0][0] + b[i][3][3];
    return sum;
}

// Integer and bool matrices take different element casts from float ones.
int pickInt(int2x3 b[2], int i, int r, int c)
{
    return b[i][r][c];
}

bool pickBool(bool2x2 b[2], int i, int r, int c)
{
    return b[i][r][c];
}

[numthreads(1, 1, 1)]
void computeMain()
{
    // cbuffer arrays passed to plain-array parameters.
    outputBuffer[0] = pick(rowBones, 0, 1, 2);
    outputBuffer[1] = pick(columnBones, 1, 3, 0);
    outputBuffer[2] = pickSized(rowBones, 1, 3, 0);
    outputBuffer[3] = pickUnsized(columnBones, 0, 1, 2);

    // cbuffer arrays assigned to plain local arrays.
    float4x4 rowCopy[2] = rowBones;
    float4x4 columnCopy[2] = columnBones;
    outputBuffer[4] = rowCopy[1][3][0];
    outputBuffer[5] = columnCopy[0][1][2];

    // A struct field array in a cbuffer, and one read through a StructuredBuffer element.
    float4x4 fieldCopy[2] = nested.m;
    outputBuffer[6] = fieldCopy[1][3][0];
    outputBuffer[7] = pick(boneBuffer[0].m, 0, 1, 2);

    // Nested arrays convert element-wise at every level.
    row_major float4x4 rowGrid[2][2];
    rowGrid[0] = rowBones;
    rowGrid[1] = nested.m;
    outputBuffer[8] = pickNested(rowGrid, 1, 0, 1, 2);

    // Plain to explicit layout, and between the two explicit layouts.
    float4x4 plain[2] = { float4x4(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16), rowBones[1] };
    outputBuffer[9] = pickRowMajor(plain, 0, 2, 1);
    column_major float4x4 columnFromRow[2] = rowBones;
    outputBuffer[10] = columnFromRow[1][3][0];
    row_major float4x4 rowFromColumn[2] = columnBones;
    outputBuffer[11] = rowFromColumn[0][1][2];

    row_major float4x4 longRows[40];
    for (int i = 0; i < 40; i++)
        longRows[i] = float4x4(float(i));
    outputBuffer[12] = sumDiagonals(longRows);

    // A compile-time constant array converts too.
    row_major float4x4 constantRows[2] = { float4x4(2.0), float4x4(3.0) };
    outputBuffer[13] = pick(constantRows, 1, 2, 2);

    row_major int2x3 intRows[2] = { int2x3(1, 2, 3, 4, 5, 6), int2x3(7, 8, 9, 10, 11, 12) };
    column_major bool2x2 boolColumns[2] = { bool2x2(true, false, false, true), bool2x2(false, true, true, false) };
    outputBuffer[14] = pickInt(intRows, 1, 0, 2);
    outputBuffer[15] = pickBool(boolColumns, 1, 0, 1) ? 1.0 : 0.0;
}

// CHECK: 6.0
// CHECK-NEXT: 51.0
// CHECK-NEXT: 28.0
// CHECK-NEXT: 41.0
// CHECK-NEXT: 28.0
// CHECK-NEXT: 41.0
// CHECK-NEXT: 92.0
// CHECK-NEXT: 106.0
// CHECK-NEXT: 70.0
// CHECK-NEXT: 10.0
// CHECK-NEXT: 28.0
// CHECK-NEXT: 41.0
// CHECK-NEXT: 1560.0
// CHECK-NEXT: 3.0
// CHECK-NEXT: 9.0
// CHECK-NEXT: 1.0
