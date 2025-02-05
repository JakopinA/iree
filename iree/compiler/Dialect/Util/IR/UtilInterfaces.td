// Copyright 2021 The IREE Authors
//
// Licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#ifndef IREE_DIALECT_UTIL_IR_UTIL_INTERFACES
#define IREE_DIALECT_UTIL_IR_UTIL_INTERFACES

include "mlir/IR/OpBase.td"

//===----------------------------------------------------------------------===//
// IREE::Util::ClosureOpInterface
//===----------------------------------------------------------------------===//

def Util_ClosureOpInterface : OpInterface<"ClosureOpInterface"> {
  let cppNamespace = "::mlir::iree_compiler::IREE::Util";

  let description = [{
    Interface for ops that follow the util dialect closure semantics (explicit
    captures, dynamic-shape awareness, and normal operand/result SSA behavior).

    Implementing this interface enables optimizations that perform manipulation
    across the closure capture boundary (outside of the op <-> regions within
    the op).
  }];

  let methods = [
    InterfaceMethod<
      /*desc=*/[{
        Returns the body region of the closure (may have multiple blocks).
      }],
      /*retTy=*/"Region &",
      /*methodName=*/"getClosureBodyRegion",
      /*args=*/(ins),
      /*methodBody=*/[{}],
      /*defaultImplementation=*/[{
        return this->getOperation()->getRegion(0);
      }]
    >,
    InterfaceMethod<
      /*desc=*/[{Returns all closure operand values.}],
      /*retTy=*/"Operation::operand_range",
      /*methodName=*/"getClosureOperands",
      /*args=*/(ins)
    >,
    InterfaceMethod<
      /*desc=*/[{Returns all closure result values.}],
      /*retTy=*/"Operation::result_range",
      /*methodName=*/"getClosureResults",
      /*args=*/(ins)
    >,
    InterfaceMethod<
      /*desc=*/[{
        Returns true if the given operation can exist in the closure.
        Not all operations that a closure can contain are guaranteed to be folded
        into the closure, such as when the operation may have side-effects.
      }],
      /*retTy=*/"bool",
      /*methodName=*/"canClosureContainOp",
      /*args=*/(ins "Operation *":$op)
    >,
    InterfaceMethod<
      /*desc=*/[{
        Clones the op while removing specified operands and results.
        The body of the op will be transferred to the new op and the entry block
        will have its arguments removed.

        The returned op will be free standing. Callers must insert it into a block
        where desired (most often just replacing the current op).
      }],
      /*retTy=*/"IREE::Util::ClosureOpInterface",
      /*methodName=*/"cloneReplacementExcludingOperandsAndResults",
      /*args=*/(ins "ArrayRef<unsigned>":$excludedOperandIndices,
                    "ArrayRef<unsigned>":$excludedResultIndices,
                    "PatternRewriter &":$rewriter)
    >,
    InterfaceMethod<
      /*desc=*/[{
        Returns a bitfield indicating how an operand is used within the closure.
      }],
      /*retTy=*/"IREE::Util::ValueAccess",
      /*methodName=*/"getOperandAccess",
      /*args=*/(ins "unsigned":$operandIndex)
    >,
    InterfaceMethod<
      /*desc=*/[{
        Returns a bitfield indicating how a result is used within the closure.
      }],
      /*retTy=*/"IREE::Util::ValueAccess",
      /*methodName=*/"getResultAccess",
      /*args=*/(ins "unsigned":$resultIndex)
    >
  ];
}

//===----------------------------------------------------------------------===//
// IREE::Util::TiedOpInterface
//===----------------------------------------------------------------------===//

def Util_TiedOpInterface : OpInterface<"TiedOpInterface"> {
  let cppNamespace = "::mlir::iree_compiler::IREE::Util";

  let description = [{
    An operation that "ties" one or more results to its operands indicating
    that the result is directly related to the operand in an operation-defined
    way. Results are still SSA values distinct from the operands and the tie is
    strictly a relationship relevant to transformations and not something that
    modifies IR definitions.

    Example:
      An operation on tensors that wants to indicate that the storage for a
      result should alias the storage for an operand, performing an "in-place"
      operation. Since tensors are still used there is no hard requirement that
      uses of the result SSA value alias the operand; a copy may still be
      introduced.

      See: flow.dispatch.workgroups

    Example:
      An operation on buffers that wants to encode activity on the buffer in IR
      (such as a barrier, a transfer operation, etc) such that the SSA use-def
      chain is representing the state of the buffer at various points in time
      but that the underlying buffers are all tied together.

      See: hal.stream.barrier

    The default implementations use an attribute on the op to store the
    relationship:
      `OptionalAttr<Util_TiedOpStorageAttr>:$tied_operands`

    Note that `$tied_operands` are indices inside the operand range returned
    by `getTiedOperandsIndexAndLength`, which may *not* be the full operand
    range of the op.
  }];

  let methods = [
    InterfaceMethod<
      /*desc=*/[{
        Returns the set of operands that results may be tied to as an
        (index, length) pair ala getODSOperandIndexAndLength.

        By default assumes all operands may be tied. If an op treats some
        operands as special then the op can override this and specify only the
        ones it will tie. For example, a cond_branch that has a condition
        operand as well as the successor operands would return only the range
        of successor operands.
      }],
      /*retTy=*/"std::pair<unsigned, unsigned>",
      /*methodName=*/"getTiedOperandsIndexAndLength", (ins),
      /*args=*/[{}],
      /*defaultImplementation=*/[{
        return {0, $_op.getNumOperands()};
      }]
    >,
    InterfaceMethod<
      /*desc=*/[{
        Walks up the SSA use-def chain to find the first defined value reachable
        from the given value by traversing tied ops. The returned value may be
        in another block if that block dominates the one the result is defined
        in.

        Note that the returned value may be a block argument and have no
        defining op, and the search will not continue past branches.
        If the result is untied then the result itself is returned.
      }],
      /*retTy=*/"Value",
      /*methodName=*/"getTiedResult",
      /*args=*/(ins "unsigned":$resultIndex),
      /*methodBody=*/[{}],
      /*defaultImplementation=*/[{
        return IREE::Util::TiedOpInterface::findTiedBaseValue($_op.getResult(resultIndex));
      }]
    >,
    InterfaceMethod<
      /*desc=*/[{
        Returns the operand tied to the given result of the op or nullptr if
        none.
      }],
      /*retTy=*/"Value",
      /*methodName=*/"getTiedResultOperand",
      /*args=*/(ins "Value":$result),
      /*methodBody=*/[{}],
      /*defaultImplementation=*/[{
        auto resultIndex = result.cast<mlir::OpResult>().getResultNumber();
        auto operandIndex = $_op.getTiedResultOperandIndex(resultIndex);
        return operandIndex.hasValue() ?
            $_op.getOperand(operandIndex.getValue()) :
            nullptr;
      }]
    >,
    InterfaceMethod<
      /*desc=*/[{
        Returns the operand index tied to the given result index, if any.

        Note that the index returned is into the full range of all operands of
        the current op.
      }],
      /*retTy=*/"::llvm::Optional<unsigned>",
      /*methodName=*/"getTiedResultOperandIndex",
      /*args=*/(ins "unsigned":$resultIndex),
      /*methodBody=*/[{}],
      /*defaultImplementation=*/[{
        return IREE::Util::detail::getTiedResultOperandIndex($_op, resultIndex);
      }]
    >,
    InterfaceMethod<
      /*desc=*/[{
        Sets the operand index tied to the given result index, if any.

        Note that the index should be into the operand range returned by
        `getTiedOperandsIndexAndLength`.
      }],
      /*retTy=*/"void",
      /*methodName=*/"setTiedResultOperandIndex",
      /*args=*/(ins "unsigned":$resultIndex,
                    "::llvm::Optional<unsigned>":$operandIndex),
      /*methodBody=*/[{}],
      /*defaultImplementation=*/[{
        return IREE::Util::detail::setTiedResultOperandIndex($_op, resultIndex, operandIndex);
      }]
    >,
    InterfaceMethod<
      /*desc=*/[{
        Returns an array containing the tied result operand indices with -1
        indicating that a result is not tied.

        Note that the index returned is into the full range of all operands of
        the current op.
      }],
      /*retTy=*/"SmallVector<int64_t, 4>",
      /*methodName=*/"getTiedResultOperandIndices",
      /*args=*/(ins),
      /*methodBody=*/[{}],
      /*defaultImplementation=*/[{
        return IREE::Util::detail::getTiedResultOperandIndices($_op);
      }]
    >,
    InterfaceMethod<
      /*desc=*/[{
        Returns true if the given flattened operand index is tied to one or more
        results.
      }],
      /*retTy=*/"bool",
      /*methodName=*/"isOperandTied",
      /*args=*/(ins "unsigned":$operandIndex),
      /*methodBody=*/[{}],
      /*defaultImplementation=*/[{
        return IREE::Util::detail::isOperandTied($_op, operandIndex);
      }]
    >,
  ];

  let extraClassDeclaration = [{
    static StringRef getStorageAttrName() { return "tied_operands"; }

    // Indicates that a result is not tied to any operand.
    static constexpr int64_t kUntiedIndex = -1;

    // Walks the SSA use-def chain to find the first defined value reachable
    // from the given value by traversing tied ops. Note that the returned
    // value may be a block argument and have no defining op.
    static Value findTiedBaseValue(Value derivedValue);
  }];

  let verify = [{
    return IREE::Util::detail::verifyTiedOp($_op);
  }];
}

//===----------------------------------------------------------------------===//
// IREE::Util::SizeAware* interfaces
//===----------------------------------------------------------------------===//

def Util_InferTypeSize : TypeInterface<"InferTypeSizeInterface"> {
  let cppNamespace = "::mlir::iree_compiler::IREE::Util";

  let description = [{
    Allows types to be queried for their size by inserting the required logic
    when required.
  }];

  let methods = [
    InterfaceMethod<
      [{Builds an expression computing the size of the value.}],
      "Value", "inferSizeFromValue", (ins "Location":$loc,
                                          "Value":$value,
                                          "OpBuilder &":$builder)
    >,
  ];
}

def Util_SizeAwareType : TypeInterface<"SizeAwareTypeInterface"> {
  let cppNamespace = "::mlir::iree_compiler::IREE::Util";

  let description = [{
    Denotes that a type is size-aware and must always have a size value
    associated with it in the IR. See `SizeAwareOp` for more information.
  }];

  let methods = [
    InterfaceMethod<
      [{Returns a size for the given sized value.}],
      "Value", "getSize", (ins "Value":$value)
    >,
  ];
}

def Util_SizeAwareOp : OpInterface<"SizeAwareOpInterface"> {
  let cppNamespace = "::mlir::iree_compiler::IREE::Util";

  let description = [{
    An operation that is able to provide size values for all size-aware operands
    and results.
  }];

  let methods = [
    InterfaceMethod<
      [{Returns a size for the given sized operand index.}],
      "Value", "getOperandSize", (ins "unsigned":$idx)
    >,
    InterfaceMethod<
      [{Returns a size for the given sized result index.}],
      "Value", "getResultSize", (ins "unsigned":$idx)
    >,
    InterfaceMethod<
      [{Returns a size for the given sized result value.}],
      "Value", "getResultSizeFromValue", (ins "Value":$value),
      /*defaultImplementation=*/[{
        for (unsigned i = 0; i < $_self->getNumResults(); ++i) {
          if ($_self->getResult(i) == value) return $_self.getResultSize(i);
        }
        return {};
      }]
    >,
  ];
}

//===----------------------------------------------------------------------===//
// IREE::Util::GlobalTypeInterface
//===----------------------------------------------------------------------===//

def Util_GlobalTypeInterface : TypeInterface<"GlobalTypeInterface"> {
  let cppNamespace = "::mlir::iree_compiler::IREE::Util";

  let description = [{
    Interface used to mark types as supported for global variables.
  }];

  let methods = [
    InterfaceMethod<
      /*desc=*/[{
        Returns true if the access to a global via a specific type is compatible
        with the storage type of the global. For example, a storage of
        `tensor<?xf32>` is compatible with an access as `tensor<4xf32>`.
      }],
      /*retTy=*/"bool",
      /*methodName=*/"isAccessStorageCompatible",
      /*args=*/(ins "Type":$accessType),
      /*methodBody=*/[{}],
      /*defaultImplementation=*/[{
        // If one is a shaped type, then they both must be and have compatible
        // shapes.
        if ($_type.template isa<ShapedType>() || accessType.isa<ShapedType>()) {
          return succeeded(mlir::verifyCompatibleShape($_type, accessType));
        }
        // Otherwise, the types must be the same.
        return $_type == accessType;
      }]
    >,
  ];
}

#endif  // IREE_DIALECT_UTIL_IR_UTIL_INTERFACES
