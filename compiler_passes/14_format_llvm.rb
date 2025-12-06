require_relative 'base'
require_relative '../lib/type_mapper'
require_relative '../compile/context'

module Walrus
  class FormatLlvm < CompilerPass
    PREAMBLE = "declare i32 @_print_int(i32)\ndeclare i32 @_print_float(double)\ndeclare i32 @_print_char(i8)\ndeclare i32 @_print_str(i8*)\ndeclare i32 @_gets_int()\n\n"

    def run(program)
      raise ArgumentError, "Expected Program" unless program.is_a?(Program)

      result = PREAMBLE

      # Emit global string constants
      global_strings = Walrus.context[:global_strings] || {}
      global_strings.each do |label, value|
        result += format_string_constant(label, value)
      end
      result += "\n" unless global_strings.empty?

      globals = program.statements.select { |s| s.is_a?(GlobalVarDeclarationWithoutInit) }
      functions = program.statements.select { |s| s.is_a?(Function) }

      # Collect global variable types from STORE_GLOBAL instructions
      global_types = collect_global_types(functions)

      functions.each { |func| result += format_function(func) + "\n" }
      globals.each { |global| result += format_global(global, global_types) }

      result
    end

    private

    def format_string_constant(label, value)
      # Escape special characters for LLVM
      # Note: value already has escape sequences processed (e.g., \n is a real newline)
      escaped = value.chars.map do |c|
        case c
        when "\n" then "\\0A"
        when "\t" then "\\09"
        when "\0" then "\\00"
        when "\\" then "\\\\"
        when '"' then "\\22"
        else c
        end
      end.join
      length = value.length + 1  # +1 for null terminator
      "#{label} = private unnamed_addr constant [#{length} x i8] c\"#{escaped}\\00\"\n"
    end

    def format_function(func)
      params = func.params.map { |p|
        llvm_type = TypeMapper.to_llvm(p.type)
        "#{llvm_type} %#{p.name}"
      }.join(', ')
      return_type = TypeMapper.to_llvm(func.type)
      result = "define #{return_type} @#{func.name}(#{params}) {\n"
      func.body.each { |block| result += format_block(block) }
      result + "}\n"
    end

    def format_block(block)
      result = "#{block.label}:\n"
      block.instructions.each { |instr| result += "    #{instr.op}\n" }
      result
    end

    def collect_global_types(functions)
      types = {}
      functions.each do |func|
        func.body.each do |block|
          block.instructions.each do |instr|
            if instr.is_a?(LLVM)
              # Parse LLVM instruction to extract global stores
              if instr.op =~ /store (i32|double|i8) .+, (i32|double|i8)\* @(\w+)/
                llvm_type = $1
                var_name = $3
                wabbit_type = TypeMapper.from_llvm(llvm_type)
                types[var_name] = wabbit_type
              end
            end
          end
        end
      end
      types
    end

    def format_global(global, global_types)
      wabbit_type = global.type || global_types[global.name]
      llvm_type = TypeMapper.to_llvm(wabbit_type)
      init_value = case llvm_type
                   when 'double' then '0.0'
                   when /\*$/ then 'null'  # pointer types
                   else '0'
                   end
      "@#{global.name} = global #{llvm_type} #{init_value}\n"
    end
  end
end
