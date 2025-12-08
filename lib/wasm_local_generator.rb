# WasmLocalGenerator - Manages local variable naming and declarations for WasmGC
#
# WebAssembly requires all local variables to be declared at the start of a function.
# This class tracks locals, generates unique names for temporaries, and produces
# the necessary local declarations.
#
# WasmGC locals are named with $ prefix: $x, $temp0, etc.

require_relative 'type_mapper_wasm'

class WasmLocalGenerator
  attr_reader :locals, :params

  def initialize
    @locals = {}        # name => wasm_type
    @params = {}        # name => wasm_type (function parameters)
    @temp_counter = 0
  end

  # Register a function parameter
  #
  # @param name [String] Parameter name
  # @param walrus_type [String] Walrus type
  def add_param(name, walrus_type)
    wasm_type = TypeMapperWasm.to_wasm(walrus_type)
    @params[name] = wasm_type
  end

  # Register a local variable
  #
  # @param name [String] Variable name
  # @param walrus_type [String] Walrus type
  def add_local(name, walrus_type)
    wasm_type = TypeMapperWasm.to_wasm(walrus_type)
    @locals[name] = wasm_type
  end

  # Generate a new temporary local variable
  #
  # @param walrus_type [String] Walrus type for the temporary
  # @return [String] The temporary variable name (without $ prefix)
  def new_temp(walrus_type = 'int')
    name = ".t#{@temp_counter}"
    @temp_counter += 1
    add_local(name, walrus_type)
    name
  end

  # Check if a name is a parameter
  #
  # @param name [String] Variable name
  # @return [Boolean]
  def param?(name)
    @params.key?(name)
  end

  # Check if a name is a local (not a parameter)
  #
  # @param name [String] Variable name
  # @return [Boolean]
  def local?(name)
    @locals.key?(name)
  end

  # Get the WasmGC type for a variable (param or local)
  #
  # @param name [String] Variable name
  # @return [String, nil] The WasmGC type or nil if not found
  def type_of(name)
    @params[name] || @locals[name]
  end

  # Format a variable name for WasmGC (add $ prefix)
  #
  # @param name [String] Variable name
  # @return [String] Formatted name with $ prefix
  def format_name(name)
    "$#{name}"
  end

  # Generate the local declarations for a function
  # Parameters are not included here as they're in the function signature
  #
  # @return [Array<String>] Local declaration instructions
  def local_declarations
    @locals.map do |name, wasm_type|
      "(local $#{name} #{wasm_type})"
    end
  end

  # Generate parameter declarations for function signature
  #
  # @return [Array<String>] Parameter declaration strings
  def param_declarations
    @params.map do |name, wasm_type|
      "(param $#{name} #{wasm_type})"
    end
  end

  # Reset the generator for a new function
  def reset
    @locals.clear
    @params.clear
    @temp_counter = 0
  end

  # Clone the current state (useful for nested scopes)
  def clone
    copy = WasmLocalGenerator.new
    copy.instance_variable_set(:@locals, @locals.dup)
    copy.instance_variable_set(:@params, @params.dup)
    copy.instance_variable_set(:@temp_counter, @temp_counter)
    copy
  end
end

# WasmGlobalRegistry - Tracks global variables for WasmGC modules
#
# Globals in WasmGC are module-level and must be declared with types and initial values.

class WasmGlobalRegistry
  attr_reader :globals

  def initialize
    @globals = {}  # name => { type: wasm_type, mutable: bool }
  end

  # Register a global variable
  #
  # @param name [String] Global variable name
  # @param walrus_type [String] Walrus type
  # @param mutable [Boolean] Whether the global is mutable
  def add_global(name, walrus_type, mutable: true)
    wasm_type = TypeMapperWasm.to_wasm(walrus_type)
    @globals[name] = { type: wasm_type, mutable: mutable }
  end

  # Check if a name is a global
  #
  # @param name [String] Variable name
  # @return [Boolean]
  def global?(name)
    @globals.key?(name)
  end

  # Get the WasmGC type for a global
  #
  # @param name [String] Global name
  # @return [String, nil] The WasmGC type or nil if not found
  def type_of(name)
    @globals[name]&.fetch(:type)
  end

  # Generate global declarations for the module
  #
  # @return [Array<String>] Global declaration instructions
  def global_declarations
    @globals.map do |name, info|
      type = info[:type]
      mutability = info[:mutable] ? "(mut #{type})" : type
      default = TypeMapperWasm.default_value(type)
      "(global $#{name} #{mutability} (#{default}))"
    end
  end

  # Reset the registry
  def reset
    @globals.clear
  end
end

# WasmLabelGenerator - Generates unique labels for control flow blocks
#
# WasmGC uses labeled blocks for structured control flow.

class WasmLabelGenerator
  def initialize(prefix = 'block')
    @prefix = prefix
    @counter = 0
  end

  # Generate a new unique label
  #
  # @return [String] A unique label name
  def next_label
    label = "$#{@prefix}#{@counter}"
    @counter += 1
    label
  end

  # Reset the counter
  def reset
    @counter = 0
  end
end
