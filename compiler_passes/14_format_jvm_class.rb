# frozen_string_literal: true

require_relative 'base'
require_relative '../lib/jvm_type_mapper'
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

      # Add static fields for global variables
      globals.each do |global|
        jvm_type_descriptor = JVMTypeMapper.to_jvm(global.type)
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

        class_writer.add_method(
          name: func.name,
          descriptor: descriptor,
          access: :public_static,
          max_stack: builder.max_stack,
          max_locals: max_locals,
          instructions: builder.instructions
        )
      end

      # Generate .class file as byte array
      class_writer.to_bytes
    end
  end
end
