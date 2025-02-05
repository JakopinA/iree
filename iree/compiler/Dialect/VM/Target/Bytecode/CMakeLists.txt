################################################################################
# Autogenerated by build_tools/bazel_to_cmake/bazel_to_cmake.py from           #
# iree/compiler/Dialect/VM/Target/Bytecode/BUILD                               #
#                                                                              #
# Use iree_cmake_extra_content from iree/build_defs.oss.bzl to add arbitrary   #
# CMake-only content.                                                          #
#                                                                              #
# To disable autogeneration for this file entirely, delete this header.        #
################################################################################

iree_add_all_subdirs()

iree_cc_library(
  NAME
    Bytecode
  HDRS
    "BytecodeModuleTarget.h"
    "TranslationFlags.h"
  SRCS
    "BytecodeEncoder.cpp"
    "BytecodeEncoder.h"
    "BytecodeModuleTarget.cpp"
    "ConstantEncoder.cpp"
    "ConstantEncoder.h"
    "DebugDatabaseBuilder.cpp"
    "DebugDatabaseBuilder.h"
    "TranslationFlags.cpp"
    "TranslationRegistration.cpp"
  DEPS
    LLVMSupport
    MLIRIR
    MLIRPass
    MLIRSupport
    MLIRTransforms
    MLIRTranslation
    iree::compiler::Dialect::Util::IR
    iree::compiler::Dialect::Util::Transforms
    iree::compiler::Dialect::VM::Analysis
    iree::compiler::Dialect::VM::IR
    iree::compiler::Dialect::VM::Transforms
    iree::compiler::Dialect::VM::Utils::CallingConvention
    iree::compiler::Dialect::VM::Utils::ConstantEncoding
    iree::compiler::Utils
    iree::schemas::bytecode_module_def_c_fbs
  PUBLIC
)

### BAZEL_TO_CMAKE_PRESERVES_ALL_CONTENT_BELOW_THIS_LINE ###
