// slang-ir-lower-array-builtin-cast.h
#pragma once

// This file defines an IR pass that lowers a `BuiltinCast` between two array types into an
// element-wise conversion. The front end produces such a cast when an array of matrices converts
// to an array of the same matrices with a different layout, e.g. `row_major float4x4[4]` to
// `float4x4[4]`. The pass runs after specialization, once every matrix layout is resolved. Arrays
// of up to 16 elements, and global constants, convert inline; longer arrays and arrays with a
// specialization-constant length convert with a loop.

namespace Slang
{

struct IRModule;

void lowerArrayBuiltinCasts(IRModule* module);

} // namespace Slang
