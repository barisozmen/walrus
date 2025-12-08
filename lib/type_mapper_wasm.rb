# TypeMapperWasm - Single Source of Truth for Walrus to WasmGC type conversions
#
# This module centralizes all type mapping logic between Walrus types and WasmGC types.
# WasmGC (WebAssembly with Garbage Collection) introduces reference types that enable
# automatic memory management.
#
# WasmGC Type System:
# - Primitive types: i32, i64, f32, f64 (same as core Wasm)
# - Reference types: (ref ...), (ref null ...) for GC-managed objects
# - String type: (ref string) or (ref (array i8)) for byte arrays
# - Struct types: (ref (struct ...)) for user-defined types
# - Array types: (ref (array T)) for dynamic arrays

module TypeMapperWasm
  # Mapping from Walrus primitive types to WasmGC types
  WALRUS_TO_WASM = {
    'int' => 'i32',
    'float' => 'f64',
    'char' => 'i32',     # Characters as Unicode code points
    'bool' => 'i32',     # Booleans as 0/1 integers
    'str' => 'i32'       # String pointer (index into string table for now)
  }.freeze

  # Default values for each WasmGC type
  WASM_DEFAULT_VALUES = {
    'i32' => 'i32.const 0',
    'i64' => 'i64.const 0',
    'f32' => 'f32.const 0.0',
    'f64' => 'f64.const 0.0'
  }.freeze

  # Convert a Walrus type to its corresponding WasmGC type
  #
  # @param walrus_type [String, Symbol] The Walrus type ('int', 'float', 'char', 'bool')
  # @return [String] The WasmGC type ('i32', 'f64', etc.)
  # @example
  #   TypeMapperWasm.to_wasm('float')  # => 'f64'
  #   TypeMapperWasm.to_wasm('int')    # => 'i32'
  def self.to_wasm(walrus_type)
    WALRUS_TO_WASM.fetch(walrus_type.to_s, 'i32')
  end

  # Convert a WasmGC type back to its Walrus type
  #
  # @param wasm_type [String] The WasmGC type ('i32', 'f64', etc.)
  # @return [String] The Walrus type ('int', 'float', 'char', 'bool')
  # @example
  #   TypeMapperWasm.from_wasm('f64')  # => 'float'
  #   TypeMapperWasm.from_wasm('i32')  # => 'int'
  def self.from_wasm(wasm_type)
    # Note: i32 could be int, char, or bool - we default to int
    WALRUS_TO_WASM.invert[wasm_type] || 'int'
  end

  # Get the default value instruction for a WasmGC type
  #
  # @param wasm_type [String] The WasmGC type
  # @return [String] The default value instruction
  def self.default_value(wasm_type)
    WASM_DEFAULT_VALUES.fetch(wasm_type, 'i32.const 0')
  end

  # Check if a Walrus type is a floating point type
  #
  # @param walrus_type [String] The Walrus type
  # @return [Boolean]
  def self.is_float?(walrus_type)
    walrus_type.to_s == 'float'
  end

  # Check if a WasmGC type is a floating point type
  #
  # @param wasm_type [String] The WasmGC type
  # @return [Boolean]
  def self.is_wasm_float?(wasm_type)
    %w[f32 f64].include?(wasm_type)
  end

  # Get the appropriate arithmetic instruction suffix
  # WasmGC uses type-prefixed instructions (i32.add, f64.add, etc.)
  #
  # @param wasm_type [String] The WasmGC type
  # @return [String] The type prefix for instructions
  def self.instruction_prefix(wasm_type)
    wasm_type
  end
end
