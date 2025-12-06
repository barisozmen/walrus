require_relative '../test_context'

class TestLLVMFormatter < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::FormatLlvm.new.run(input)
    assert_equal expected, result
  end

  TESTCASES = {
    # Simple function with no parameters
    Program.new([
      Function.new('get_constant', [], [
        BLOCK.new('entry', [
          LLVM.new('br label %L1')
        ]),
        BLOCK.new('L1', [
          LLVM.new('ret i32 42')
        ])
      ])
    ]) =>
      <<~LLVM,
        declare i32 @_print_int(i32)
        declare i32 @_print_float(double)
        declare i32 @_print_char(i8)
        declare i32 @_print_str(i8*)
        declare i32 @_gets_int()

        define i32 @get_constant() {
        entry:
            br label %L1
        L1:
            ret i32 42
        }

      LLVM

    # Function with two parameters
    Program.new([
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
      ])
    ]) =>
      <<~LLVM,
        declare i32 @_print_int(i32)
        declare i32 @_print_float(double)
        declare i32 @_print_char(i8)
        declare i32 @_print_str(i8*)
        declare i32 @_gets_int()

        define i32 @add(i32 %.arg_x, i32 %.arg_y) {
        entry:
            %x = alloca i32
            store i32 %.arg_x, i32* %x
            %y = alloca i32
            store i32 %.arg_y, i32* %y
            br label %L1
        L1:
            %r = alloca i32
            %.1 = load i32, i32* %x
            %.2 = load i32, i32* %y
            %.3 = add i32 %.1, %.2
            store i32 %.3, i32* %r
            %.4 = load i32, i32* %r
            ret i32 %.4
        }

      LLVM

    # Global variable declaration
    Program.new([
      Function.new('main', [], [
        BLOCK.new('entry', [
          LLVM.new('br label %L1')
        ]),
        BLOCK.new('L1', [
          LLVM.new('store i32 42, i32* @result'),
          LLVM.new('ret i32 0')
        ])
      ]),
      GlobalVarDeclarationWithoutInit.new('result')
    ]) =>
      <<~LLVM,
        declare i32 @_print_int(i32)
        declare i32 @_print_float(double)
        declare i32 @_print_char(i8)
        declare i32 @_print_str(i8*)
        declare i32 @_gets_int()

        define i32 @main() {
        entry:
            br label %L1
        L1:
            store i32 42, i32* @result
            ret i32 0
        }

        @result = global i32 0
      LLVM

    # Function with call and print
    Program.new([
      Function.new('add', [Parameter.new('.arg_x'), Parameter.new('.arg_y')], [
        BLOCK.new('entry', [
          LLVM.new('%x = alloca i32'),
          LLVM.new('store i32 %.arg_x, i32* %x'),
          LLVM.new('%y = alloca i32'),
          LLVM.new('store i32 %.arg_y, i32* %y'),
          LLVM.new('br label %L1')
        ]),
        BLOCK.new('L1', [
          LLVM.new('%.1 = load i32, i32* %x'),
          LLVM.new('%.2 = load i32, i32* %y'),
          LLVM.new('%.3 = add i32 %.1, %.2'),
          LLVM.new('ret i32 %.3')
        ])
      ]),
      Function.new('main', [], [
        BLOCK.new('entry', [
          LLVM.new('br label %L2')
        ]),
        BLOCK.new('L2', [
          LLVM.new('%.4 = call i32 (i32, i32) @add(i32 3, i32 4)'),
          LLVM.new('call i32 (i32) @_print_int(i32 %.4)'),
          LLVM.new('ret i32 0')
        ])
      ])
    ]) =>
      <<~LLVM,
        declare i32 @_print_int(i32)
        declare i32 @_print_float(double)
        declare i32 @_print_char(i8)
        declare i32 @_print_str(i8*)
        declare i32 @_gets_int()

        define i32 @add(i32 %.arg_x, i32 %.arg_y) {
        entry:
            %x = alloca i32
            store i32 %.arg_x, i32* %x
            %y = alloca i32
            store i32 %.arg_y, i32* %y
            br label %L1
        L1:
            %.1 = load i32, i32* %x
            %.2 = load i32, i32* %y
            %.3 = add i32 %.1, %.2
            ret i32 %.3
        }

        define i32 @main() {
        entry:
            br label %L2
        L2:
            %.4 = call i32 (i32, i32) @add(i32 3, i32 4)
            call i32 (i32) @_print_int(i32 %.4)
            ret i32 0
        }

      LLVM

    # Multiple blocks with branches
    Program.new([
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
    ]) =>
      <<~LLVM
        declare i32 @_print_int(i32)
        declare i32 @_print_float(double)
        declare i32 @_print_char(i8)
        declare i32 @_print_str(i8*)
        declare i32 @_gets_int()

        define i32 @conditional(i32 %.arg_x) {
        entry:
            %x = alloca i32
            store i32 %.arg_x, i32* %x
            br label %L1
        L1:
            %.1 = load i32, i32* %x
            %.2 = icmp sgt i32 %.1, 0
            br i1 %.2, label %L2, label %L3
        L2:
            ret i32 1
        L3:
            ret i32 0
        }

      LLVM
  }

  generate_tests
end
