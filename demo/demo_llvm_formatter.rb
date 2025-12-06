#!/usr/bin/env ruby
#
# Demonstration of LLVM Formatter
#
# This demonstrates the complete compilation pipeline:
# Source code → Passes 1-13 → LLVM IR text

require_relative '../model'
require_relative '../compiler_passes/01_tokenizer'
require_relative '../compiler_passes/02_parser'
require_relative '../compiler_passes/03_fold_constants'
require_relative '../compiler_passes/04_deinitialize_variable_declarations'
require_relative '../compiler_passes/05_resolve_variable_scopes'
require_relative '../compiler_passes/06_gather_top_level_statements_into_main'
require_relative '../compiler_passes/07_ensure_all_functions_have_explicit_returns'
require_relative '../compiler_passes/08_lower_expressions_to_instructions'
require_relative '../compiler_passes/09_lower_statements_to_instructions'
require_relative '../compiler_passes/10_merge_statements_into_basic_blocks'
require_relative '../compiler_passes/11_flatten_control_flow'
require_relative '../compiler_passes/12_generate_llvm_code'
require_relative '../compiler_passes/13_add_llvm_entry_blocks'
require_relative '../compiler_passes/14_format_llvm'

# Simple Walrus program with a function
source = <<~WAB
  func add(x int, y int) int {
      return x + y;
  }

  print add(3, 4);
WAB

puts "=" * 70
puts "WAB SOURCE CODE"
puts "=" * 70
puts source
puts

# Run all compiler passes
ast = Walrus::Tokenizer.new.run(source)
ast = Walrus::Parser.new.run(ast)
ast = Walrus::FoldConstants.new.run(ast)
ast = Walrus::DeinitializeVariableDeclarations.new.run(ast)
ast = Walrus::ResolveVariableScopes.new.run(ast)
ast = Walrus::GatherTopLevelStatementsIntoMain.new.run(ast)
ast = Walrus::EnsureAllFunctionsHaveExplicitReturns.new.run(ast)
ast = Walrus::LowerExpressionsToInstructions.new.run(ast)
ast = Walrus::LowerStatementsToInstructions.new.run(ast)
ast = Walrus::MergeStatementsIntoBasicBlocks.new.run(ast)
ast = Walrus::FlattenControlFlow.new.run(ast)
ast = Walrus::GenerateLLVMCode.new.run(ast)
ast = Walrus::AddLlvmEntryBlocks.new.run(ast)

puts "=" * 70
puts "LLVM IR OUTPUT"
puts "=" * 70

# Format as LLVM IR
llvm_ir = Walrus::FormatLlvm.new.run(ast)
puts llvm_ir

puts "=" * 70
puts "Key Transformations"
puts "=" * 70
puts "• Functions become: define i32 @name(params) { ... }"
puts "• Parameters get type annotations: i32 %.arg_x"
puts "• Entry blocks allocate and store parameters"
puts "• LLVM instructions are extracted from LLVM() wrappers"
puts "• Preamble declares @_print_int for I/O"
puts
puts "This output can be compiled with: clang -c out.ll"
