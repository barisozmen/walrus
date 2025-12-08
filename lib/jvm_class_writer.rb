# frozen_string_literal: true

require_relative 'jvm_type_mapper'
require_relative 'jvm_bytecode_builder'
require 'tempfile'
require 'fileutils'

module Walrus
  # Generates JVM .class files from bytecode instructions
  # Uses Java source generation + javac compilation for simplicity
  class JVMClassWriter
    attr_reader :class_name, :fields, :methods

    def initialize(class_name)
      @class_name = class_name
      @fields = []
      @methods = []
    end

    # Add a static field
    def add_static_field(name:, descriptor:, access: :public_static)
      @fields << {
        name: name,
        descriptor: descriptor,
        access: access
      }
    end

    # Add a static method
    def add_method(name:, descriptor:, access: :public_static, max_stack:, max_locals:, instructions:)
      @methods << {
        name: name,
        descriptor: descriptor,
        access: access,
        max_stack: max_stack,
        max_locals: max_locals,
        instructions: instructions
      }
    end

    # Generate .class file bytes
    # Returns path to .class file
    def to_bytes
      # Generate Java source code
      java_source = generate_java_source

      # Write to temp file
      temp_dir = Dir.mktmpdir('walrus_jvm')
      java_file = File.join(temp_dir, "#{class_name}.java")
      File.write(java_file, java_source)

      # Compile with javac
      compile_cmd = "javac #{java_file}"
      unless system(compile_cmd, out: File::NULL, err: File::NULL)
        # Show error for debugging
        system(compile_cmd)
        raise "javac compilation failed for #{java_file}"
      end

      # Read .class file
      class_file = File.join(temp_dir, "#{class_name}.class")
      bytes = File.binread(class_file)

      # Save Java source for debugging (in /tmp)
      debug_java_file = "/tmp/#{class_name}.java"
      FileUtils.cp(java_file, debug_java_file)

      # Clean up temp dir
      FileUtils.rm_rf(temp_dir)

      bytes
    end

    private

    def generate_java_source
      source = "public class #{class_name} {\n"

      # Generate fields
      @fields.each do |field|
        java_type = descriptor_to_java_type(field[:descriptor])
        source += "    public static #{java_type} #{field[:name]};\n"
      end

      source += "\n"

      # Generate methods
      @methods.each do |method|
        source += generate_method_source(method)
        source += "\n"
      end

      source += "}\n"
      source
    end

    def generate_method_source(method)
      # Parse descriptor to get params and return type
      descriptor = method[:descriptor]
      return "    // ERROR: Invalid descriptor #{descriptor}\n" unless descriptor =~ /\(([^)]*)\)(.+)/

      params_desc = $1
      return_desc = $2

      # Convert to Java types
      return_type = descriptor_to_java_type(return_desc)
      param_types = parse_param_descriptors(params_desc)

      # Generate parameter list
      param_list = param_types.each_with_index.map { |type, i| "#{type} p#{i}" }.join(', ')

      source = "    public static #{return_type} #{method[:name]}(#{param_list}) {\n"

      # Convert bytecode instructions to Java
      source += convert_bytecode_to_java(method[:instructions], method[:max_locals])

      source += "    }\n"
      source
    end

    def convert_bytecode_to_java(instructions, max_locals)
      java_code = ""

      # Declare local variables
      (0...max_locals).each do |i|
        java_code += "        int local#{i} = 0;\n"  # Default init
        java_code += "        double dlocal#{i} = 0.0;\n"
      end

      # Simulate stack with array
      java_code += "        java.util.Stack<Object> stack = new java.util.Stack<>();\n"
      java_code += "\n"

      # Convert each instruction
      instructions.each do |instr|
        comment = "        // #{instr}\n"
        java_code += comment

        case instr.opcode
        # Constants
        when :iconst_0 then java_code += "        stack.push(0);\n"
        when :iconst_1 then java_code += "        stack.push(1);\n"
        when :iconst_2 then java_code += "        stack.push(2);\n"
        when :iconst_3 then java_code += "        stack.push(3);\n"
        when :iconst_4 then java_code += "        stack.push(4);\n"
        when :iconst_5 then java_code += "        stack.push(5);\n"
        when :iconst_m1 then java_code += "        stack.push(-1);\n"
        when :bipush, :sipush then java_code += "        stack.push(#{instr.operands[0]});\n"
        when :ldc then java_code += "        stack.push(#{format_constant(instr.operands[0])});\n"
        when :dconst_0 then java_code += "        stack.push(0.0);\n"
        when :dconst_1 then java_code += "        stack.push(1.0);\n"
        when :ldc2_w then java_code += "        stack.push(#{instr.operands[0]});\n"

        # Arithmetic
        when :iadd
          java_code += "        stack.push((Integer)stack.pop() + (Integer)stack.pop());\n"
        when :dadd
          java_code += "        { double b = (Double)stack.pop(); double a = (Double)stack.pop(); stack.push(a + b); }\n"
        when :isub
          java_code += "        { int b = (Integer)stack.pop(); int a = (Integer)stack.pop(); stack.push(a - b); }\n"
        when :dsub
          java_code += "        { double b = (Double)stack.pop(); double a = (Double)stack.pop(); stack.push(a - b); }\n"
        when :imul
          java_code += "        { int b = (Integer)stack.pop(); int a = (Integer)stack.pop(); stack.push(a * b); }\n"
        when :dmul
          java_code += "        { double b = (Double)stack.pop(); double a = (Double)stack.pop(); stack.push(a * b); }\n"
        when :idiv
          java_code += "        { int b = (Integer)stack.pop(); int a = (Integer)stack.pop(); stack.push(a / b); }\n"
        when :ddiv
          java_code += "        { double b = (Double)stack.pop(); double a = (Double)stack.pop(); stack.push(a / b); }\n"
        when :ineg
          java_code += "        stack.push(-(Integer)stack.pop());\n"
        when :dneg
          java_code += "        stack.push(-(Double)stack.pop());\n"

        # Local variables
        when :iload, :iload_0, :iload_1, :iload_2, :iload_3
          idx = extract_index(instr)
          java_code += "        stack.push(local#{idx});\n"
        when :dload, :dload_0, :dload_1, :dload_2, :dload_3
          idx = extract_index(instr)
          java_code += "        stack.push(dlocal#{idx});\n"
        when :istore, :istore_0, :istore_1, :istore_2, :istore_3
          idx = extract_index(instr)
          java_code += "        local#{idx} = (Integer)stack.pop();\n"
        when :dstore, :dstore_0, :dstore_1, :dstore_2, :dstore_3
          idx = extract_index(instr)
          java_code += "        dlocal#{idx} = (Double)stack.pop();\n"

        # Static fields
        when :getstatic
          field_ref = instr.operands[0]  # "ClassName.fieldName"
          # Special case for System.out
          if field_ref == 'java/lang/System.out'
            java_code += "        stack.push(System.out);\n"
          else
            java_code += "        stack.push(#{field_ref});\n"
          end
        when :putstatic
          field_ref = instr.operands[0]
          java_code += "        #{field_ref} = (#{get_field_type(instr.operands[1])})stack.pop();\n"

        # Stack manipulation
        when :swap
          java_code += "        { Object temp1 = stack.pop(); Object temp2 = stack.pop(); stack.push(temp1); stack.push(temp2); }\n"
        when :dup
          java_code += "        { Object temp = stack.peek(); stack.push(temp); }\n"
        when :pop
          java_code += "        stack.pop();\n"

        # Method calls
        when :invokestatic
          method_ref = instr.operands[0]  # "ClassName.methodName"
          descriptor = instr.operands[1]
          java_code += generate_invoke_static(method_ref, descriptor)
        when :invokevirtual
          method_ref = instr.operands[0]  # "ClassName.methodName"
          descriptor = instr.operands[1]
          java_code += generate_invoke_virtual(method_ref, descriptor)

        # Return
        when :ireturn
          java_code += "        return (Integer)stack.pop();\n"
        when :dreturn
          java_code += "        return (Double)stack.pop();\n"
        when :areturn
          java_code += "        return stack.pop();\n"
        when :return
          java_code += "        return;\n"

        # Control flow (labels)
        when :label
          java_code += "    #{instr.operands[0]}:\n"
        when :goto
          java_code += "        // goto #{instr.operands[0]} (not implemented in Java source)\n"
        when :if_icmplt, :if_icmpgt, :if_icmple, :if_icmpge, :if_icmpeq, :if_icmpne
          java_code += "        // #{instr.opcode} (not fully implemented)\n"

        # Comparisons
        when :dcmpg
          java_code += "        { double b = (Double)stack.pop(); double a = (Double)stack.pop(); stack.push(a > b ? 1 : (a == b ? 0 : -1)); }\n"

        else
          java_code += "        // TODO: #{instr.opcode}\n"
        end
      end

      java_code
    end

    def extract_index(instr)
      case instr.opcode
      when :iload_0, :dload_0, :istore_0, :dstore_0, :aload_0, :astore_0 then 0
      when :iload_1, :dload_1, :istore_1, :dstore_1, :aload_1, :astore_1 then 1
      when :iload_2, :dload_2, :istore_2, :dstore_2, :aload_2, :astore_2 then 2
      when :iload_3, :dload_3, :istore_3, :dstore_3, :aload_3, :astore_3 then 3
      else instr.operands[0]
      end
    end

    def format_constant(value)
      case value
      when String then "\"#{escape_java_string(value)}\""
      when Integer then value.to_s
      when Float then "#{value}d"
      else value.to_s
      end
    end

    def escape_java_string(str)
      str.gsub('\\', '\\\\\\\\').gsub('"', '\\"').gsub("\n", '\\n').gsub("\t", '\\t')
    end

    def generate_invoke_static(method_ref, descriptor)
      # Parse method ref: "ClassName.methodName"
      # descriptor is like "(II)I" meaning (int, int) -> int
      parts = method_ref.split('.')
      class_name = parts[0..-2].join('.')
      method_name = parts[-1]

      # Parse descriptor to get parameter count and return type
      descriptor =~ /\(([^)]*)\)(.+)/
      params_desc = $1
      return_desc = $2

      # Count parameters
      param_count = count_params(params_desc)

      # Pop parameters from stack
      if param_count > 0
        args = (0...param_count).map { |i| "stack.pop()" }.reverse.join(', ')
        call = "#{method_ref}(#{args})"
      else
        call = "#{method_ref}()"
      end

      # Generate call with return value handling
      if return_desc == 'V'
        # Void return
        "        #{call};\n"
      else
        # Push return value onto stack
        "        stack.push(#{call});\n"
      end
    end

    def generate_invoke_virtual(method_ref, descriptor)
      # Special case for System.out.println
      if method_ref == "java/io/PrintStream.println"
        # Pop the argument (int, double, etc.)
        # Pop the PrintStream object
        arg = "stack.pop()"
        obj = "stack.pop()"
        return "        { Object arg = #{arg}; Object obj = #{obj}; System.out.println(arg); }\n"
      end
      "        // invokevirtual #{method_ref}#{descriptor}\n"
    end

    def get_field_type(descriptor)
      descriptor_to_java_type(descriptor)
    end

    def descriptor_to_java_type(descriptor)
      case descriptor
      when 'I' then 'int'
      when 'D' then 'double'
      when 'Z' then 'boolean'
      when 'C' then 'char'
      when 'V' then 'void'
      when 'Ljava/lang/String;' then 'String'
      when /^L(.+);$/ then $1.gsub('/', '.')  # Object type
      when /^\[/ then descriptor_to_array_type(descriptor)  # Array type
      else 'Object'
      end
    end

    def descriptor_to_array_type(descriptor)
      # Simple array handling
      element_type = descriptor_to_java_type(descriptor[1..-1])
      "#{element_type}[]"
    end

    def parse_param_descriptors(params_desc)
      types = []
      i = 0
      while i < params_desc.length
        case params_desc[i]
        when 'I' then types << 'int'
        when 'D' then types << 'double'
        when 'Z' then types << 'boolean'
        when 'C' then types << 'char'
        when 'L'
          # Find semicolon
          end_idx = params_desc.index(';', i)
          class_name = params_desc[i+1...end_idx].gsub('/', '.')
          types << class_name
          i = end_idx
        when '['
          # Array type
          j = i + 1
          j += 1 while params_desc[j] == '['
          if params_desc[j] == 'L'
            end_idx = params_desc.index(';', j)
            types << descriptor_to_array_type(params_desc[i..end_idx])
            i = end_idx
          else
            types << descriptor_to_array_type(params_desc[i..j])
            i = j
          end
        end
        i += 1
      end
      types
    end

    def count_params(params_desc)
      parse_param_descriptors(params_desc).length
    end
  end
end
