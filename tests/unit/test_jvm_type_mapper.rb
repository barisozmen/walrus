require_relative '../test_context'
require_relative '../../lib/jvm_type_mapper'

class TestJVMTypeMapper < Minitest::Test
  include Walrus

  def test_basic_type_mapping
    assert_equal 'I', JVMTypeMapper.to_jvm('int')
    assert_equal 'D', JVMTypeMapper.to_jvm('float')
    assert_equal 'Z', JVMTypeMapper.to_jvm('bool')
    assert_equal 'C', JVMTypeMapper.to_jvm('char')
    assert_equal 'Ljava/lang/String;', JVMTypeMapper.to_jvm('str')
  end

  def test_reverse_mapping
    assert_equal 'int', JVMTypeMapper.from_jvm('I')
    assert_equal 'float', JVMTypeMapper.from_jvm('D')
    assert_equal 'bool', JVMTypeMapper.from_jvm('Z')
    assert_equal 'char', JVMTypeMapper.from_jvm('C')
    assert_equal 'str', JVMTypeMapper.from_jvm('Ljava/lang/String;')
  end

  def test_method_descriptor_no_params
    descriptor = JVMTypeMapper.to_method_descriptor([], 'int')
    assert_equal '()I', descriptor
  end

  def test_method_descriptor_single_param
    descriptor = JVMTypeMapper.to_method_descriptor(['int'], 'int')
    assert_equal '(I)I', descriptor
  end

  def test_method_descriptor_multiple_params
    descriptor = JVMTypeMapper.to_method_descriptor(['int', 'float', 'bool'], 'int')
    assert_equal '(IDZ)I', descriptor
  end

  def test_method_descriptor_with_string
    descriptor = JVMTypeMapper.to_method_descriptor(['str', 'int'], 'str')
    assert_equal '(Ljava/lang/String;I)Ljava/lang/String;', descriptor
  end

  def test_slot_width
    assert_equal 1, JVMTypeMapper.slot_width('int')
    assert_equal 2, JVMTypeMapper.slot_width('float')  # double takes 2 slots
    assert_equal 1, JVMTypeMapper.slot_width('bool')
    assert_equal 1, JVMTypeMapper.slot_width('char')
    assert_equal 1, JVMTypeMapper.slot_width('str')
  end

  def test_internal_name_conversion
    assert_equal 'java/lang/String', JVMTypeMapper.to_internal_name('java.lang.String')
    assert_equal 'java/util/List', JVMTypeMapper.to_internal_name('java.util.List')
  end

  def test_field_descriptor
    assert_equal 'I', JVMTypeMapper.to_field_descriptor('int')
    assert_equal 'D', JVMTypeMapper.to_field_descriptor('float')
  end

  def test_invalid_type_raises_error
    assert_raises(RuntimeError) do
      JVMTypeMapper.to_jvm('invalid_type')
    end
  end
end
