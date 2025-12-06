require_relative 'base'
require_relative '../compiler_error'

module Walrus
  # Flattens If and While statements into basic blocks linked by GOTO and CBRANCH
  # Every block must end with RETURN, GOTO, or CBRANCH
  class FlattenControlFlow < CompilerPass
    def initialize
      @label_gen = LabelGenerator.new
    end

    def run(input)
      @label_gen = LabelGenerator.new
      @loop_stack = []

      case input
      when Program
        Program.new(input.statements.map { |stmt| transform_top_level(stmt) })
      when Function
        transform_top_level(input)
      when Array
        flatten_function_body(input)
      else
        flatten_function_body([input])
      end
    end

    private

    def transform_top_level(stmt)
      case stmt
      when Function
        Function.new(stmt.name, stmt.params, flatten_function_body(stmt.body), type: stmt.type)
      else
        stmt # Global declarations pass through
      end
    end

    # Flatten function body: process statements in REVERSE order
    # Each statement needs to know where control flows next (next_label)
    def flatten_function_body(statements)
      return [] if statements.empty?

      # Process in reverse to determine control flow links
      blocks = []
      next_label = nil

      statements.reverse.each do |stmt|
        result = link_statement(stmt, next_label)
        blocks = result[:blocks] + blocks
        next_label = result[:entry_label]
      end

      blocks
    end

    # Link a statement to the next block
    # Returns: { blocks: [...], entry_label: "first block label" }
    def link_statement(stmt, next_label)
      case stmt
      when BLOCK
        link_block(stmt, next_label)
      when If
        link_if(stmt, next_label)
      when While
        link_while(stmt, next_label)
      when Break
        link_break(stmt, next_label)
      when Continue
        link_continue(stmt, next_label)
      else
        raise CompilerError::CodegenError.new("Unexpected statement type: #{stmt.class}", nil)
      end
    end

    # Simple block: add GOTO to next_label (unless ends with RETURN)
    def link_block(block, next_label)
      new_label = @label_gen.gen_label
      last_instr = block.instructions.last

      if last_instr.is_a?(RETURN)
        # Already terminates, no modification needed
        { blocks: [BLOCK.new(new_label, block.instructions)], entry_label: new_label }
      elsif next_label
        # Add GOTO to link to next block
        linked = BLOCK.new(new_label, block.instructions + [GOTO.new(next_label)])
        { blocks: [linked], entry_label: new_label }
      else
        # No next block (end of function)
        { blocks: [BLOCK.new(new_label, block.instructions)], entry_label: new_label }
      end
    end

    # If statement:
    # Create test block, link then/else branches to next_label
    def link_if(if_stmt, next_label)
      test_label = @label_gen.gen_label

      # Recursively link branches
      then_result = link_branch(if_stmt.then_block, next_label)
      else_result = link_branch(if_stmt.else_block, next_label)

      # Test block with CBRANCH
      test_block = BLOCK.new(
        test_label,
        if_stmt.condition.instructions + [
          CBRANCH.new(then_result[:entry_label], else_result[:entry_label])
        ]
      )

      {
        blocks: [test_block] + then_result[:blocks] + else_result[:blocks],
        entry_label: test_label
      }
    end

    # While loop:
    # Create test block, link body back to test
    def link_while(while_stmt, next_label)
      test_label = @label_gen.gen_label

      # Push loop context before processing body
      @loop_stack.push({ break_label: next_label, continue_label: test_label })

      # Link body to loop back to test
      body_result = link_branch(while_stmt.body, test_label)

      # Pop loop context after processing body
      @loop_stack.pop

      # Test block with CBRANCH
      test_block = BLOCK.new(
        test_label,
        while_stmt.condition.instructions + [
          CBRANCH.new(body_result[:entry_label], next_label)
        ]
      )

      {
        blocks: [test_block] + body_result[:blocks],
        entry_label: test_label
      }
    end

    # Break: convert to GOTO(next_label)
    def link_break(break_node, next_label)
      loop_context = @loop_stack.last
      raise CompilerError::CodegenError.new("break outside loop", break_node.loc) unless loop_context

      label = @label_gen.gen_label
      block = BLOCK.new(label, [GOTO.new(loop_context[:break_label])])
      { blocks: [block], entry_label: label }
    end

    # Continue: convert to GOTO(test_label)
    def link_continue(continue_node, next_label)
      loop_context = @loop_stack.last
      raise CompilerError::CodegenError.new("continue outside loop", continue_node.loc) unless loop_context

      label = @label_gen.gen_label
      block = BLOCK.new(label, [GOTO.new(loop_context[:continue_label])])
      { blocks: [block], entry_label: label }
    end

    # Link a branch (list of statements) to next_label
    def link_branch(statements, next_label)
      return { blocks: [], entry_label: next_label } if statements.empty?

      blocks = []
      next_lbl = next_label

      statements.reverse.each do |stmt|
        result = link_statement(stmt, next_lbl)
        blocks = result[:blocks] + blocks
        next_lbl = result[:entry_label]
      end

      { blocks: blocks, entry_label: next_lbl }
    end
  end
end
