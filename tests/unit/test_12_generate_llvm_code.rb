require_relative '../test_context'

class TestGenerateLLVMCode < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::GenerateLLVMCode.new.run(input)
    if result != expected
      # debugger
    end
    assert_equal expected, result
  end

  TESTCASES = {
    # Simple literal: PUSH becomes value in stack
    BLOCK.new('L0', [PUSH.new(42), RETURN.new]) =>
      BLOCK.new('L0', [LLVM.new('ret i32 42')]),

    # Arithmetic: ADD pops two, generates add instruction
    BLOCK.new('L0', [PUSH.new(10), PUSH.new(20), ADD.new, RETURN.new]) =>
      BLOCK.new('L0', [
        LLVM.new('%.1 = add i32 10, 20'),
        LLVM.new('ret i32 %.1')
      ]),

    # Multiplication
    BLOCK.new('L0', [PUSH.new(5), PUSH.new(6), MUL.new, RETURN.new]) =>
      BLOCK.new('L0', [
        LLVM.new('%.1 = mul i32 5, 6'),
        LLVM.new('ret i32 %.1')
      ]),

    # Comparison: LT produces icmp slt
    BLOCK.new('L0', [PUSH.new(10), PUSH.new(20), LT.new, CBRANCH.new('L1', 'L2')]) =>
      BLOCK.new('L0', [
        LLVM.new('%.1 = icmp slt i32 10, 20'),
        LLVM.new('br i1 %.1, label %L1, label %L2')
      ]),

    # Load/Store local variable
    BLOCK.new('L0', [
      LOCAL.new('x'),
      PUSH.new(42),
      STORE_LOCAL.new('x'),
      LOAD_LOCAL.new('x'),
      RETURN.new
    ]) =>
      BLOCK.new('L0', [
        LLVM.new('%x = alloca i32'),
        LLVM.new('store i32 42, i32* %x'),
        LLVM.new('%.1 = load i32, i32* %x'),
        LLVM.new('ret i32 %.1')
      ]),

    # Load/Store global variable
    BLOCK.new('L0', [
      PUSH.new(100),
      STORE_GLOBAL.new('total'),
      LOAD_GLOBAL.new('total'),
      RETURN.new
    ]) =>
      BLOCK.new('L0', [
        LLVM.new('store i32 100, i32* @total'),
        LLVM.new('%.1 = load i32, i32* @total'),
        LLVM.new('ret i32 %.1')
      ]),

    # GOTO
    BLOCK.new('L0', [PUSH.new(1), STORE_LOCAL.new('x'), GOTO.new('L1')]) =>
      BLOCK.new('L0', [
        LLVM.new('store i32 1, i32* %x'),
        LLVM.new('br label %L1')
      ]),

    # PRINT statement
    BLOCK.new('L0', [PUSH.new(42), PRINT.new, PUSH.new(0), RETURN.new]) =>
      BLOCK.new('L0', [
        LLVM.new('call i32 (i32) @_print_int(i32 42)'),
        LLVM.new('ret i32 0')
      ]),

    # Complex expression: (x + 1) * 2
    BLOCK.new('L0', [
      LOAD_LOCAL.new('x'),
      PUSH.new(1),
      ADD.new,
      PUSH.new(2),
      MUL.new,
      RETURN.new
    ]) =>
      BLOCK.new('L0', [
        LLVM.new('%.1 = load i32, i32* %x'),
        LLVM.new('%.2 = add i32 %.1, 1'),
        LLVM.new('%.3 = mul i32 %.2, 2'),
        LLVM.new('ret i32 %.3')
      ]),

    # Function call with one argument
    BLOCK.new('L0', [
      PUSH.new(10),
      CALL.new('fact', 1),
      RETURN.new
    ]) =>
      BLOCK.new('L0', [
        LLVM.new('%.1 = call i32 (i32) @fact(i32 10)'),
        LLVM.new('ret i32 %.1')
      ]),

    # Subtraction
    BLOCK.new('L0', [PUSH.new(100), PUSH.new(30), SUB.new, RETURN.new]) =>
      BLOCK.new('L0', [
        LLVM.new('%.1 = sub i32 100, 30'),
        LLVM.new('ret i32 %.1')
      ]),

    # Division
    BLOCK.new('L0', [PUSH.new(20), PUSH.new(4), DIV.new, RETURN.new]) =>
      BLOCK.new('L0', [
        LLVM.new('%.1 = sdiv i32 20, 4'),
        LLVM.new('ret i32 %.1')
      ]),

    # Float addition
    BLOCK.new('L0', [PUSH.new(20.0), PUSH.new(4.0), ADD.new, RETURN.new]) =>
      BLOCK.new('L0', [
        LLVM.new('%.1 = fadd double 20.0, 4.0'),
        LLVM.new('ret double %.1')
      ]),

    # Float subtraction
    BLOCK.new('L0', [PUSH.new(20.0), PUSH.new(4.0), SUB.new, RETURN.new]) =>
      BLOCK.new('L0', [
        LLVM.new('%.1 = fsub double 20.0, 4.0'),
        LLVM.new('ret double %.1')
      ]),

    # Float multiplication
    BLOCK.new('L0', [PUSH.new(20.0), PUSH.new(4.0), MUL.new, RETURN.new]) =>
      BLOCK.new('L0', [
        LLVM.new('%.1 = fmul double 20.0, 4.0'),
        LLVM.new('ret double %.1')
      ]),

    # Float division
    BLOCK.new('L0', [PUSH.new(20.0), PUSH.new(4.0), DIV.new, RETURN.new]) =>
      BLOCK.new('L0', [
        LLVM.new('%.1 = fdiv double 20.0, 4.0'),
        LLVM.new('ret double %.1')
      ]),

    # Float comparison
    BLOCK.new('L0', [PUSH.new(20.0), PUSH.new(4.0), LT.new, RETURN.new]) =>
      BLOCK.new('L0', [
        LLVM.new('%.1 = fcmp olt double 20.0, 4.0'),
        LLVM.new('ret i1 %.1')
      ]),
  }


  generate_tests
end
