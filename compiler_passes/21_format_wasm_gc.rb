require_relative 'base'
require_relative '../lib/type_mapper_wasm'
require_relative '../compile/context'

module Walrus
  # Formats the program as WebAssembly Text (WAT) format with GC extensions
  #
  # Output format:
  #   (module
  #     ;; Type definitions (for GC types)
  #     ;; Import declarations (runtime functions)
  #     ;; Global variable declarations
  #     ;; Function definitions
  #     ;; Export declarations
  #   )
  #
  class FormatWasmGC < CompilerPass
    # Runtime function imports
    RUNTIME_IMPORTS = <<~WAT
      ;; Runtime imports
      (import "runtime" "print_int" (func $_print_int (param i32) (result i32)))
      (import "runtime" "print_float" (func $_print_float (param f64) (result i32)))
      (import "runtime" "print_char" (func $_print_char (param i32) (result i32)))
      (import "runtime" "print_str" (func $_print_str (param i32) (result i32)))
      (import "runtime" "gets_int" (func $_gets_int (result i32)))
    WAT

    def run(program)
      raise ArgumentError, "Expected Program" unless program.is_a?(Program)

      result = "(module\n"
      result += indent(RUNTIME_IMPORTS, 2)
      result += "\n"

      # Collect globals and functions
      globals = program.statements.select { |s| s.is_a?(GlobalVarDeclarationWithoutInit) }
      functions = program.statements.select { |s| s.is_a?(Function) }

      # Collect global types from the functions
      global_types = collect_global_types(functions)

      # Emit global declarations
      if globals.any?
        result += "\n  ;; Global variables\n"
        globals.each do |global|
          result += "  #{format_global(global, global_types)}\n"
        end
      end

      # Emit functions
      result += "\n  ;; Functions\n"
      functions.each do |func|
        result += format_function(func)
        result += "\n"
      end

      result += ")\n"
      result
    end

    private

    def indent(text, spaces)
      prefix = " " * spaces
      text.lines.map { |line| line.strip.empty? ? line : "#{prefix}#{line}" }.join
    end

    # Collect global types from STORE_GLOBAL instructions
    def collect_global_types(functions)
      types = {}
      functions.each do |func|
        func.body.each do |block|
          next unless block.respond_to?(:instructions)
          block.instructions.each do |instr|
            if instr.is_a?(WASM) && instr.op =~ /global\.set \$(\w+)/
              var_name = $1
              # Try to infer type from preceding instruction
              types[var_name] ||= 'int'  # Default to int
            end
          end
        end
      end
      types
    end

    # Format a global variable declaration
    def format_global(global, global_types)
      walrus_type = global.type || global_types[global.name] || 'int'
      wasm_type = TypeMapperWasm.to_wasm(walrus_type)
      default_value = TypeMapperWasm.default_value(wasm_type)
      "(global $#{global.name} (mut #{wasm_type}) (#{default_value}))"
    end

    # Format a function definition
    def format_function(func)
      # Get locals generator if available
      locals_gen = func.instance_variable_get(:@wasm_locals) if func.instance_variable_defined?(:@wasm_locals)

      # Build parameter list
      params = func.params.map do |p|
        wasm_type = TypeMapperWasm.to_wasm(p.type)
        "(param $#{p.name} #{wasm_type})"
      end.join(" ")

      # Build result type
      return_type = TypeMapperWasm.to_wasm(func.type || 'int')
      result_decl = "(result #{return_type})"

      # Build local declarations
      local_decls = ""
      if locals_gen
        locals = locals_gen.local_declarations
        if locals.any?
          local_decls = "\n    " + locals.join("\n    ")
        end
      end

      # Build function signature
      export_decl = func.name == 'main' ? "(export \"main\") " : ""
      result = "  (func $#{func.name} #{export_decl}#{params} #{result_decl}#{local_decls}\n"

      # Emit function body
      func.body.each do |block|
        result += format_block(block, 4)
      end

      result += "  )\n"
      result
    end

    # Format a block of instructions
    def format_block(block, indent_level)
      result = ""
      indent_str = " " * indent_level

      # Add block label comment (except for structured blocks which handle their own labels)
      unless block.is_a?(WASM_STRUCTURED_BLOCK)
        result += "#{indent_str};; #{block.label}\n" if block.respond_to?(:label) && block.label
      end

      instructions = block.respond_to?(:instructions) ? block.instructions : []

      instructions.each do |instr|
        result += format_instruction(instr, indent_level)
      end

      result
    end

    # Format a single instruction
    def format_instruction(instr, indent_level)
      indent_str = " " * indent_level

      case instr
      when WASM
        op = instr.op
        comment = instr.comment ? " ;; #{instr.comment}" : ""

        # Handle structured keywords with indentation
        case op
        when /^(block|loop|if)\b/
          "#{indent_str}#{op}#{comment}\n"
        when /^(else)\b/
          "#{" " * (indent_level - 2)}#{op}#{comment}\n"
        when /^(end)\b/
          "#{" " * (indent_level - 2)}#{op}#{comment}\n"
        else
          "#{indent_str}#{op}#{comment}\n"
        end

      when WASM_GOTO
        # Unconverted GOTO - should have been handled by control flow pass
        "#{indent_str};; GOTO #{instr.label} (unconverted)\n"

      when WASM_CBRANCH
        # Unconverted CBRANCH - should have been handled by control flow pass
        "#{indent_str};; CBRANCH #{instr.true_label} #{instr.false_label} (unconverted)\n"

      when WASM_STRUCTURED_BLOCK
        # Recursively format structured block
        format_block(instr, indent_level)

      when BLOCK
        # Nested block (shouldn't happen often)
        format_block(instr, indent_level)

      else
        "#{indent_str};; Unknown: #{instr.class}\n"
      end
    end
  end
end
