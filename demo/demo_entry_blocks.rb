#!/usr/bin/env ruby
#
# Demonstration of LLVM Entry Blocks Pass
#
# This demonstrates how the AddLlvmEntryBlocks pass transforms functions
# to properly handle argument passing by value with mutation support.

require_relative '../model'
require_relative '../format'
require_relative '../compiler_passes/13_add_llvm_entry_blocks'

# Create a sample function BEFORE the entry blocks pass
# This represents what the function looks like after pass 12 (GenerateLLVMCode)
before = Function.new('add', [Parameter.new('x'), Parameter.new('y')], [
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

puts "=" * 70
puts "BEFORE: Pass 12 - GenerateLLVMCode"
puts "=" * 70
puts "Problem: %x and %y are not allocated!"
puts "The load instructions will fail because these variables don't exist."
puts
puts Formatter.new.format_statement(before)
puts

# Apply the AddLlvmEntryBlocks pass
pass = Walrus::AddLlvmEntryBlocks.new
after = pass.run(before)

puts "=" * 70
puts "AFTER: Pass 13 - AddLlvmEntryBlocks"
puts "=" * 70
puts "Solution:"
puts "1. Parameters renamed: x → .arg_x, y → .arg_y"
puts "2. Entry block allocates memory: %x = alloca i32, %y = alloca i32"
puts "3. Entry block stores arguments: store i32 %.arg_x, i32* %x"
puts "4. Entry block branches to first block: br label %L1"
puts
puts Formatter.new.format_statement(after)
puts

puts "=" * 70
puts "Key Points"
puts "=" * 70
puts "• Arguments are passed by value (copy)"
puts "• Each parameter needs its own memory location for mutation"
puts "• The entry block separates LLVM's register-based parameters"
puts "  from our memory-based variables"
puts "• This enables proper semantics: modifying x in the function"
puts "  doesn't affect the caller's variable"
