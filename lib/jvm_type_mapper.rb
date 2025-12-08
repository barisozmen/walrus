# frozen_string_literal: true

module Walrus
  # Maps Walrus types to JVM type descriptors and signatures
  module JVMTypeMapper
    # Convert Walrus type to JVM type descriptor
    # @param walrus_type [String] Walrus type ('int', 'float', 'bool', 'char', 'str')
    # @return [String] JVM type descriptor ('I', 'D', 'Z', 'C', 'Ljava/lang/String;')
    def self.to_jvm(walrus_type)
      case walrus_type
      when 'int'   then 'I'
      when 'float' then 'D'  # Walrus float maps to JVM double
      when 'bool'  then 'Z'
      when 'char'  then 'C'
      when 'str'   then 'Ljava/lang/String;'
      else raise "Unknown Walrus type: #{walrus_type}"
      end
    end

    # Convert JVM type descriptor back to Walrus type (for debugging)
    def self.from_jvm(jvm_descriptor)
      case jvm_descriptor
      when 'I' then 'int'
      when 'D' then 'float'
      when 'Z' then 'bool'
      when 'C' then 'char'
      when 'Ljava/lang/String;' then 'str'
      else raise "Unknown JVM descriptor: #{jvm_descriptor}"
      end
    end

    # Convert to JVM method descriptor
    # Example: (['int', 'int'], 'int') => "(II)I"
    # @param param_types [Array<String>] Parameter types
    # @param return_type [String] Return type
    # @return [String] JVM method descriptor
    def self.to_method_descriptor(param_types, return_type)
      param_sig = param_types.map { |t| to_jvm(t) }.join
      ret_sig = to_jvm(return_type)
      "(#{param_sig})#{ret_sig}"
    end

    # Convert to JVM internal name (for classes)
    # Example: "java.lang.String" => "java/lang/String"
    def self.to_internal_name(class_name)
      class_name.gsub('.', '/')
    end

    # Get JVM local variable slot width (double/long take 2 slots)
    # @param walrus_type [String] Walrus type
    # @return [Integer] Number of slots (1 or 2)
    def self.slot_width(walrus_type)
      walrus_type == 'float' ? 2 : 1
    end

    # Get JVM type for field descriptor
    # Same as to_jvm but useful for field declarations
    def self.to_field_descriptor(walrus_type)
      to_jvm(walrus_type)
    end
  end
end
