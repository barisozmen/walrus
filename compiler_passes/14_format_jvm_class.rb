# frozen_string_literal: true

require_relative 'base'
require_relative '../lib/jvm_type_mapper'
require_relative '../lib/jvm_bytecode_builder'
require_relative '../lib/jvm_class_writer'

module Walrus
  # Generates JVM .class file from bytecode
  # Uses JVMClassWriter to compile Java source + javac
  class FormatJVMClass < CompilerPass
    def run(program)
      raise ArgumentError, "Expected Program" unless program.is_a?(Program)

      class_name = Walrus.context[:class_name] || 'WalrusProgram'
      class_writer = JVMClassWriter.new(class_name)

      # Extract globals and functions
      globals = program.statements.select { |s| s.is_a?(GlobalVarDeclarationWithoutInit) }
      functions = program.statements.select { |s| s.is_a?(Function) }

      # Collect global variable types from STORE_GLOBAL instructions
      # (same approach as LLVM backend - types are inferred from stores, not declarations)
      global_types = collect_global_types(functions)

      # Add static fields for global variables
      globals.each do |global|
        global_type = global_types[global.name]
        unless global_type
          # Default to int if no stores found (shouldn't happen for valid programs)
          global_type = 'int'
        end

        jvm_type_descriptor = JVMTypeMapper.to_jvm(global_type)
        class_writer.add_static_field(
          name: global.name,
          descriptor: jvm_type_descriptor,
          access: :public_static
        )
      end

      # Add static methods for each function
      jvm_builders = Walrus.context[:jvm_builders] || {}
      local_var_maps = Walrus.context[:local_var_maps] || {}
      max_locals_map = Walrus.context[:max_locals_map] || {}

      has_walrus_main = false

      functions.each do |func|
        builder = jvm_builders[func.name]
        next unless builder

        param_descriptors = func.params.map { |p| JVMTypeMapper.to_jvm(p.type) }
        return_descriptor = JVMTypeMapper.to_jvm(func.type)
        descriptor = JVMTypeMapper.to_method_descriptor(
          func.params.map(&:type),
          func.type
        )

        max_locals = max_locals_map[func.name] || 10

        # Add the Walrus function as a static method
        if func.name == 'main'
          method_name = 'walrus_main'
          has_walrus_main = true
        else
          method_name = func.name
        end

        class_writer.add_method(
          name: method_name,
          descriptor: descriptor,
          access: :public_static,
          max_stack: builder.max_stack,
          max_locals: max_locals,
          instructions: builder.instructions
        )
      end

      # Add Java main method wrapper if walrus_main was generated
      if has_walrus_main
        add_java_main_wrapper(class_writer)
      end

      # Generate .class file as byte array
      class_writer.to_bytes
    end

    private

    # Collect global variable types by scanning STORE_GLOBAL instructions
    # (similar to LLVM backend's approach)
    def collect_global_types(functions)
      types = {}
      functions.each do |func|
        func.body.each do |block|
          block.instructions.each do |instr|
            if instr.is_a?(STORE_GLOBAL)
              types[instr.name] = instr.type
            end
          end
        end
      end
      types
    end

    # Add Java main method wrapper that calls walrus_main
    def add_java_main_wrapper(class_writer)
      builder = JVMBytecodeBuilder.new
      class_name = Walrus.context[:class_name] || 'WalrusProgram'

      # Call walrus_main() method
      builder.invokestatic(class_name, 'walrus_main', '()I')
      # Pop return value (ignore it)
      builder.emit(:pop)
      # Return void
      builder.emit(:return)

      class_writer.add_method(
        name: 'main',
        descriptor: '([Ljava/lang/String;)V',
        access: :public_static,
        max_stack: 2,
        max_locals: 1,
        instructions: builder.instructions
      )
    end
  end
end
