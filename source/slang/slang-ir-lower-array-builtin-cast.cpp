// slang-ir-lower-array-builtin-cast.cpp
#include "slang-ir-lower-array-builtin-cast.h"

#include "slang-ir-insts.h"
#include "slang-ir-util.h"
#include "slang-ir.h"

namespace Slang
{

// Arrays up to this length are converted inline, one element at a time; longer arrays, and arrays
// whose length is a specialization constant, are converted by a loop in a helper function.
static const IRIntegerValue kMaxArrayCastLengthToUnroll = 16;

struct ArrayBuiltinCastLoweringContext
{
    IRModule* module;

    // The loop helper for each (destination type, source type) pair, so that every conversion
    // between the same two array types calls one function.
    Dictionary<KeyValuePair<IRInst*, IRInst*>, IRFunc*> loopFuncs;

    // Convert `value` to `toType`, where the two types are the same except for matrix layouts.
    // An array converts element-wise; a matrix converts with the same cast as a single
    // layout-converting matrix, e.g. `row_major float4x4` to `float4x4`.
    IRInst* emitConversion(IRBuilder& builder, IRType* toType, IRInst* value)
    {
        auto fromType = value->getDataType();
        if (isTypeEqual(toType, fromType))
            return value;

        auto toArrayType = as<IRArrayType>(toType);
        if (!toArrayType)
            return builder.emitCast(toType, value);

        // The front end only forms this cast between arrays of equal length. The two lengths need
        // not be one IR value, though: a specialization-constant length is loaded separately for
        // each array type that names it.
        auto fromArrayType = as<IRArrayType>(fromType);
        SLANG_RELEASE_ASSERT(fromArrayType && "array BuiltinCast from a non-array value");

        auto count = as<IRIntLit>(toArrayType->getElementCount());
        bool canUnroll = count && count->getValue() <= kMaxArrayCastLengthToUnroll;
        if (!canUnroll && getParentFunc(builder.getInsertLoc().getParent()))
        {
            IRInst* args[] = {value};
            return builder.emitCallInst(toType, getLoopFunc(toArrayType, fromArrayType), 1, args);
        }

        // A global constant cannot call a function, and its array length is always a literal.
        SLANG_RELEASE_ASSERT(
            count && "array BuiltinCast at global scope with a non-literal length");
        List<IRInst*> elements;
        for (IRIntegerValue i = 0; i < count->getValue(); i++)
        {
            elements.add(emitConversion(
                builder,
                toArrayType->getElementType(),
                builder.emitElementExtract(value, i)));
        }
        return builder.emitMakeArray(toType, (UInt)elements.getCount(), elements.getBuffer());
    }

    // Return a function that converts a `fromType` array to a `toType` array with a loop over its
    // elements, for arrays too long to unroll or whose length is a specialization constant.
    IRFunc* getLoopFunc(IRArrayType* toType, IRArrayType* fromType)
    {
        auto key = KeyValuePair<IRInst*, IRInst*>(toType, fromType);
        if (auto func = loopFuncs.tryGetValue(key))
            return *func;

        IRBuilder builder(module);
        builder.setInsertInto(module);
        auto func = builder.createFunc();
        IRType* paramTypes[] = {fromType};
        func->setFullType(builder.getFuncType(1, paramTypes, toType));
        builder.addNameHintDecoration(func, UnownedStringSlice("convertArrayMatrixLayout"));
        builder.setInsertInto(func);
        builder.emitBlock();
        auto param = builder.emitParam(fromType);
        auto resultVar = builder.emitVar(toType);

        IRBlock* loopBodyBlock;
        IRBlock* loopBreakBlock;
        auto index = emitLoopBlocks(
            &builder,
            builder.getIntValue(builder.getIntType(), 0),
            builder.emitCast(builder.getIntType(), toType->getElementCount()),
            loopBodyBlock,
            loopBreakBlock);

        builder.setInsertBefore(loopBodyBlock->getFirstOrdinaryInst());
        auto element = emitConversion(
            builder,
            toType->getElementType(),
            builder.emitElementExtract(param, index));
        builder.emitStore(builder.emitElementAddress(resultVar, index), element);

        builder.setInsertInto(loopBreakBlock);
        builder.emitReturn(builder.emitLoad(resultVar));

        loopFuncs.add(key, func);
        return func;
    }

    void processModule()
    {
        List<IRInst*> casts;
        collectArrayCasts(module->getModuleInst(), casts);
        for (auto cast : casts)
        {
            IRBuilder builder(cast);
            builder.setInsertBefore(cast);
            auto converted = emitConversion(builder, cast->getDataType(), cast->getOperand(0));
            cast->replaceUsesWith(converted);
            cast->removeAndDeallocate();
        }
    }

    // Collect every `BuiltinCast` whose result is an array, outside of generics: a generic's
    // casts are lowered in its specializations.
    void collectArrayCasts(IRInst* parent, List<IRInst*>& outCasts)
    {
        for (auto child : parent->getChildren())
        {
            if (as<IRGeneric>(child))
                continue;
            if (child->getOp() == kIROp_BuiltinCast && as<IRArrayType>(child->getDataType()))
                outCasts.add(child);
            collectArrayCasts(child, outCasts);
        }
    }
};

void lowerArrayBuiltinCasts(IRModule* module)
{
    ArrayBuiltinCastLoweringContext context;
    context.module = module;
    context.processModule();
}

} // namespace Slang
