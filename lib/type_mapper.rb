# TypeMapper - Single Source of Truth for Walrus to LLVM type conversions
#
# This module centralizes all type mapping logic between Walrus types and LLVM types.
# Previously, this mapping was duplicated in 7+ locations across the codebase.
#
# Refactoring following Martin Fowler's DRY principle and Single Source of Truth.

module TypeMapper
  # Mapping from Walrus primitive types to LLVM IR types
  Walrus_TO_LLVM = {
    'int' => 'i32',
    'float' => 'double',
    'char' => 'i8',
    'bool' => 'i1',
    'str' => 'i8*'
  }.freeze

  # Convert a Walrus type to its corresponding LLVM IR type
  #
  # @param wabbit_type [String, Symbol] The Walrus type ('int', 'float', 'char', 'bool')
  # @return [String] The LLVM IR type ('i32', 'double', 'i8', 'i1')
  # @example
  #   TypeMapper.to_llvm('float')  # => 'double'
  #   TypeMapper.to_llvm('int')    # => 'i32'
  def self.to_llvm(wabbit_type)
    Walrus_TO_LLVM.fetch(wabbit_type.to_s, 'i32')
  end

  # Convert an LLVM IR type back to its Walrus type
  #
  # @param llvm_type [String] The LLVM IR type ('i32', 'double', 'i8', 'i1')
  # @return [String] The Walrus type ('int', 'float', 'char', 'bool')
  # @example
  #   TypeMapper.from_llvm('double')  # => 'float'
  #   TypeMapper.from_llvm('i32')     # => 'int'
  def self.from_llvm(llvm_type)
    Walrus_TO_LLVM.invert[llvm_type] || 'int'
  end
end
