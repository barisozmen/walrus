require_relative '../test_context'
require_relative '../../compiler_passes/13_add_llvm_entry_blocks'

class TestAddLlvmEntryBlocks < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::AddLlvmEntryBlocks.new.run(input)
    assert_equal expected, result
  end

  TESTCASES = {
    # Function with single parameter
    Function.new('add1', [Parameter.new('n')], [
      BLOCK.new('L1', [
        LLVM.new('%r = alloca i32'),
        LLVM.new('%.1 = load i32, i32* %n'),
        LLVM.new('%.2 = add i32 %.1, 1'),
        LLVM.new('store i32 %.2, i32* %r'),
        LLVM.new('%.3 = load i32, i32* %r'),
        LLVM.new('ret i32 %.3')
      ])
    ]) =>
      Function.new('add1', [Parameter.new('.arg_n')], [
        BLOCK.new('entry', [
          LLVM.new('%n = alloca i32'),
          LLVM.new('store i32 %.arg_n, i32* %n'),
          LLVM.new('br label %L1')
        ]),
        BLOCK.new('L1', [
          LLVM.new('%r = alloca i32'),
          LLVM.new('%.1 = load i32, i32* %n'),
          LLVM.new('%.2 = add i32 %.1, 1'),
          LLVM.new('store i32 %.2, i32* %r'),
          LLVM.new('%.3 = load i32, i32* %r'),
          LLVM.new('ret i32 %.3')
        ])
      ]),

    # Function with two parameters
    Function.new('add', [Parameter.new('x'), Parameter.new('y')], [
      BLOCK.new('L1', [
        LLVM.new('%r = alloca i32'),
        LLVM.new('%.1 = load i32, i32* %x'),
        LLVM.new('%.2 = load i32, i32* %y'),
        LLVM.new('%.3 = add i32 %.1, %.2'),
        LLVM.new('store i32 %.3, i32* %r'),
        LLVM.new('%.4 = load i32, i32* %r'),
        LLVM.new('ret i32 %.4')
      ])
    ]) =>
      Function.new('add', [Parameter.new('.arg_x'), Parameter.new('.arg_y')], [
        BLOCK.new('entry', [
          LLVM.new('%x = alloca i32'),
          LLVM.new('store i32 %.arg_x, i32* %x'),
          LLVM.new('%y = alloca i32'),
          LLVM.new('store i32 %.arg_y, i32* %y'),
          LLVM.new('br label %L1')
        ]),
        BLOCK.new('L1', [
          LLVM.new('%r = alloca i32'),
          LLVM.new('%.1 = load i32, i32* %x'),
          LLVM.new('%.2 = load i32, i32* %y'),
          LLVM.new('%.3 = add i32 %.1, %.2'),
          LLVM.new('store i32 %.3, i32* %r'),
          LLVM.new('%.4 = load i32, i32* %r'),
          LLVM.new('ret i32 %.4')
        ])
      ]),

    # Function with no parameters (still needs entry block)
    Function.new('get_constant', [], [
      BLOCK.new('L1', [
        LLVM.new('ret i32 42')
      ])
    ]) =>
      Function.new('get_constant', [], [
        BLOCK.new('entry', [
          LLVM.new('br label %L1')
        ]),
        BLOCK.new('L1', [
          LLVM.new('ret i32 42')
        ])
      ]),

    # Function with three parameters
    Function.new('sum3', [Parameter.new('a'), Parameter.new('b'), Parameter.new('c')], [
      BLOCK.new('L1', [
        LLVM.new('%.1 = load i32, i32* %a'),
        LLVM.new('%.2 = load i32, i32* %b'),
        LLVM.new('%.3 = add i32 %.1, %.2'),
        LLVM.new('%.4 = load i32, i32* %c'),
        LLVM.new('%.5 = add i32 %.3, %.4'),
        LLVM.new('ret i32 %.5')
      ])
    ]) =>
      Function.new('sum3', [Parameter.new('.arg_a'), Parameter.new('.arg_b'), Parameter.new('.arg_c')], [
        BLOCK.new('entry', [
          LLVM.new('%a = alloca i32'),
          LLVM.new('store i32 %.arg_a, i32* %a'),
          LLVM.new('%b = alloca i32'),
          LLVM.new('store i32 %.arg_b, i32* %b'),
          LLVM.new('%c = alloca i32'),
          LLVM.new('store i32 %.arg_c, i32* %c'),
          LLVM.new('br label %L1')
        ]),
        BLOCK.new('L1', [
          LLVM.new('%.1 = load i32, i32* %a'),
          LLVM.new('%.2 = load i32, i32* %b'),
          LLVM.new('%.3 = add i32 %.1, %.2'),
          LLVM.new('%.4 = load i32, i32* %c'),
          LLVM.new('%.5 = add i32 %.3, %.4'),
          LLVM.new('ret i32 %.5')
        ])
      ]),

    # Function with multiple blocks (entry should link to first)
    Function.new('conditional', [Parameter.new('x')], [
      BLOCK.new('L1', [
        LLVM.new('%.1 = load i32, i32* %x'),
        LLVM.new('%.2 = icmp sgt i32 %.1, 0'),
        LLVM.new('br i1 %.2, label %L2, label %L3')
      ]),
      BLOCK.new('L2', [
        LLVM.new('ret i32 1')
      ]),
      BLOCK.new('L3', [
        LLVM.new('ret i32 0')
      ])
    ]) =>
      Function.new('conditional', [Parameter.new('.arg_x')], [
        BLOCK.new('entry', [
          LLVM.new('%x = alloca i32'),
          LLVM.new('store i32 %.arg_x, i32* %x'),
          LLVM.new('br label %L1')
        ]),
        BLOCK.new('L1', [
          LLVM.new('%.1 = load i32, i32* %x'),
          LLVM.new('%.2 = icmp sgt i32 %.1, 0'),
          LLVM.new('br i1 %.2, label %L2, label %L3')
        ]),
        BLOCK.new('L2', [
          LLVM.new('ret i32 1')
        ]),
        BLOCK.new('L3', [
          LLVM.new('ret i32 0')
        ])
      ])
  }

  generate_tests
end
