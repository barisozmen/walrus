require_relative '../test_context'

class TestAllocateJVMLocalVariables < Minitest::Test
  def test_simple_function_with_params
    func = Function.new('add', [
      Parameter.new('x', type: 'int'),
      Parameter.new('y', type: 'int')
    ], [], type: 'int')

    context = {}
    pass = Walrus::AllocateJVMLocalVariables.new
    pass.transform_function(func, context)

    local_map = context[:local_var_maps]['add']
    assert_equal 0, local_map['x']
    assert_equal 1, local_map['y']
    assert_equal 2, context[:max_locals_map]['add']
  end

  def test_function_with_double_param
    func = Function.new('compute', [
      Parameter.new('x', type: 'int'),
      Parameter.new('y', type: 'float'),  # Takes 2 slots
      Parameter.new('z', type: 'int')
    ], [], type: 'int')

    context = {}
    pass = Walrus::AllocateJVMLocalVariables.new
    pass.transform_function(func, context)

    local_map = context[:local_var_maps]['compute']
    assert_equal 0, local_map['x']
    assert_equal 1, local_map['y']
    assert_equal 3, local_map['z']  # y takes slots 1-2, z starts at 3
    assert_equal 4, context[:max_locals_map]['compute']
  end

  def test_function_with_local_variables
    func = Function.new('test', [
      Parameter.new('x', type: 'int')
    ], [
      BLOCK.new('L0', [
        LOCAL.new('temp', type: 'int'),
        LOCAL.new('result', type: 'float')
      ])
    ], type: 'int')

    context = {}
    pass = Walrus::AllocateJVMLocalVariables.new
    pass.transform_function(func, context)

    local_map = context[:local_var_maps]['test']
    assert_equal 0, local_map['x']
    assert_equal 1, local_map['temp']
    assert_equal 2, local_map['result']  # float takes 2 slots (2-3)
    assert_equal 4, context[:max_locals_map]['test']
  end

  def test_function_with_multiple_locals_in_blocks
    func = Function.new('test', [], [
      BLOCK.new('L0', [LOCAL.new('a', type: 'int')]),
      BLOCK.new('L1', [LOCAL.new('b', type: 'int')]),
      BLOCK.new('L2', [LOCAL.new('c', type: 'int')])
    ], type: 'int')

    context = {}
    pass = Walrus::AllocateJVMLocalVariables.new
    pass.transform_function(func, context)

    local_map = context[:local_var_maps]['test']
    assert_equal 0, local_map['a']
    assert_equal 1, local_map['b']
    assert_equal 2, local_map['c']
    assert_equal 3, context[:max_locals_map]['test']
  end

  def test_duplicate_local_declarations_ignored
    # Same variable declared in multiple blocks should only get one slot
    func = Function.new('test', [], [
      BLOCK.new('L0', [LOCAL.new('x', type: 'int')]),
      BLOCK.new('L1', [LOCAL.new('x', type: 'int')])  # Duplicate
    ], type: 'int')

    context = {}
    pass = Walrus::AllocateJVMLocalVariables.new
    pass.transform_function(func, context)

    local_map = context[:local_var_maps]['test']
    assert_equal 0, local_map['x']
    assert_equal 1, context[:max_locals_map]['test']
  end

  def test_function_with_no_params_or_locals
    func = Function.new('empty', [], [
      BLOCK.new('L0', [PUSH.new(42), RETURN.new])
    ], type: 'int')

    context = {}
    pass = Walrus::AllocateJVMLocalVariables.new
    pass.transform_function(func, context)

    local_map = context[:local_var_maps]['empty']
    assert_equal 0, local_map.size
    assert_equal 0, context[:max_locals_map]['empty']
  end

  def test_all_doubles_allocation
    func = Function.new('doubles', [
      Parameter.new('a', type: 'float'),
      Parameter.new('b', type: 'float')
    ], [
      BLOCK.new('L0', [LOCAL.new('c', type: 'float')])
    ], type: 'float')

    context = {}
    pass = Walrus::AllocateJVMLocalVariables.new
    pass.transform_function(func, context)

    local_map = context[:local_var_maps]['doubles']
    assert_equal 0, local_map['a']  # Slots 0-1
    assert_equal 2, local_map['b']  # Slots 2-3
    assert_equal 4, local_map['c']  # Slots 4-5
    assert_equal 6, context[:max_locals_map]['doubles']
  end
end
