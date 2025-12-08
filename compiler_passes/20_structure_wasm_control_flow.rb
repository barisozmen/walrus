require_relative 'base'
require_relative '../lib/type_mapper_wasm'

module Walrus
  # Transforms flat CFG with GOTO/CBRANCH into WasmGC's structured control flow
  #
  # WebAssembly requires structured control flow - no arbitrary jumps. This pass
  # analyzes the CFG produced by FlattenControlFlow and reconstructs proper
  # block/loop/if structures.
  #
  # Control flow patterns from FlattenControlFlow:
  #
  # 1. If-then-else pattern:
  #    L_test: [..., CBRANCH(L_then, L_else)]
  #    L_then: [..., GOTO(L_merge)]
  #    L_else: [..., GOTO(L_merge)]
  #    L_merge: [...]
  #
  # 2. While loop pattern:
  #    L_test: [..., CBRANCH(L_body, L_exit)]
  #    L_body: [..., GOTO(L_test)]
  #    L_exit: [...]
  #
  # 3. Linear (no branches):
  #    L0: [..., GOTO(L1)]
  #    L1: [..., GOTO(L2)]
  #    ...
  #
  # WasmGC structured control flow:
  #   (block $label ... (br $label) ... end)  - forward branch out
  #   (loop $label ... (br $label) ... end)   - backward branch in
  #   (if (then ...) (else ...) end)          - conditional
  #
  class StructureWasmControlFlow < AstTransformerBasedCompilerPass
    def transform_function(node, context)
      return node if node.body.empty?

      # Build CFG analysis
      cfg = analyze_cfg(node.body)

      # Restructure the blocks
      structured_body = restructure_cfg(node.body, cfg)

      func = Function.new(node.name, node.params, structured_body)
      func.type = node.type

      # Preserve locals info if present
      if node.instance_variable_defined?(:@wasm_locals)
        func.instance_variable_set(:@wasm_locals, node.instance_variable_get(:@wasm_locals))
      end

      func
    end

    private

    # Analyze the CFG structure
    def analyze_cfg(blocks)
      cfg = {
        labels: {},           # label -> block
        successors: {},       # label -> [successor labels]
        predecessors: {},     # label -> [predecessor labels]
        back_edges: [],       # [(from, to)] for loops
        loop_headers: Set.new # labels that are loop headers
      }

      # Index blocks by label
      blocks.each { |b| cfg[:labels][b.label] = b }

      # Build successor/predecessor relationships
      blocks.each do |block|
        cfg[:successors][block.label] = []
        cfg[:predecessors][block.label] ||= []

        last_instr = block.instructions.last
        case last_instr
        when WASM_GOTO
          cfg[:successors][block.label] << last_instr.label
          cfg[:predecessors][last_instr.label] ||= []
          cfg[:predecessors][last_instr.label] << block.label
        when WASM_CBRANCH
          cfg[:successors][block.label] << last_instr.true_label
          cfg[:successors][block.label] << last_instr.false_label
          [last_instr.true_label, last_instr.false_label].each do |target|
            cfg[:predecessors][target] ||= []
            cfg[:predecessors][target] << block.label
          end
        end
      end

      # Detect back edges (loops) using DFS
      detect_back_edges(cfg, blocks.first.label)

      cfg
    end

    # Detect back edges using DFS
    def detect_back_edges(cfg, start_label)
      visited = Set.new
      in_stack = Set.new

      dfs = lambda do |label|
        return if visited.include?(label)

        visited.add(label)
        in_stack.add(label)

        cfg[:successors][label]&.each do |succ|
          if in_stack.include?(succ)
            # Back edge found - this is a loop
            cfg[:back_edges] << [label, succ]
            cfg[:loop_headers].add(succ)
          else
            dfs.call(succ)
          end
        end

        in_stack.delete(label)
      end

      dfs.call(start_label)
    end

    # Restructure CFG into WasmGC structured control flow
    def restructure_cfg(blocks, cfg)
      return blocks if blocks.empty?

      # For simple cases, process blocks in order
      result = []
      processed = Set.new
      block_map = blocks.each_with_object({}) { |b, h| h[b.label] = b }

      # Process starting from first block
      process_block(blocks.first.label, block_map, cfg, result, processed, nil)

      result
    end

    # Process a block and its successors
    def process_block(label, block_map, cfg, result, processed, context)
      return if processed.include?(label)
      return unless block_map[label]

      block = block_map[label]
      processed.add(label)

      last_instr = block.instructions.last
      other_instrs = block.instructions[0...-1]

      case last_instr
      when WASM_CBRANCH
        # Conditional branch - determine if it's an if or a loop test
        true_label = last_instr.true_label
        false_label = last_instr.false_label

        # Check if this is a while loop pattern
        if cfg[:loop_headers].include?(label)
          # This block is a loop header - the test block of a while
          result << create_loop_structure(label, block, true_label, false_label, block_map, cfg, processed)
        else
          # This is an if-then-else
          result << create_if_structure(label, block, true_label, false_label, block_map, cfg, processed)
        end

      when WASM_GOTO
        # Check if this is a back edge (loop continuation)
        if cfg[:loop_headers].include?(last_instr.label) && processed.include?(last_instr.label)
          # This is a loop back-edge - emit br to loop label
          new_instrs = other_instrs + [WASM.new("br $loop_#{last_instr.label}")]
          result << BLOCK.new(block.label, new_instrs)
        else
          # Forward edge - just continue
          new_instrs = other_instrs  # Remove GOTO, flow falls through
          result << BLOCK.new(block.label, new_instrs) unless new_instrs.empty?
          process_block(last_instr.label, block_map, cfg, result, processed, context)
        end

      else
        # No control flow at end - terminal block (return, etc.)
        result << block
      end
    end

    # Create a loop structure for while loops
    def create_loop_structure(test_label, test_block, body_label, exit_label, block_map, cfg, processed)
      loop_label = "loop_#{test_label}"

      # Get the test condition instructions (everything except CBRANCH)
      test_instrs = test_block.instructions[0...-1]

      # Get body block
      body_block = block_map[body_label]
      body_instrs = []
      if body_block
        processed.add(body_label)
        # Body ends with GOTO back to test - replace with br to loop
        body_instrs = body_block.instructions.map do |instr|
          if instr.is_a?(WASM_GOTO) && instr.label == test_label
            WASM.new("br $#{loop_label}")
          else
            instr
          end
        end
      end

      # Build structured loop:
      # (block $exit
      #   (loop $loop
      #     test_instrs
      #     (br_if $exit (i32.eqz condition))  ; exit if condition is false
      #     body_instrs
      #     (br $loop)  ; continue loop
      #   )
      # )
      exit_block_label = "exit_#{test_label}"

      structured_instrs = [
        WASM.new("block $#{exit_block_label}"),
        WASM.new("loop $#{loop_label}"),
        *test_instrs,
        WASM.new("i32.eqz"),  # Invert condition (br_if exits when condition is false)
        WASM.new("br_if $#{exit_block_label}"),
        *body_instrs,
        WASM.new("br $#{loop_label}"),
        WASM.new("end"),  # end loop
        WASM.new("end"),  # end block
      ]

      # Mark exit block as processed and continue from there
      processed.add(exit_label)

      WASM_STRUCTURED_BLOCK.new(test_label, structured_instrs, exit_label)
    end

    # Create an if-then-else structure
    def create_if_structure(test_label, test_block, then_label, else_label, block_map, cfg, processed)
      # Get test condition instructions
      test_instrs = test_block.instructions[0...-1]

      # Get then block
      then_block = block_map[then_label]
      then_instrs = []
      then_next = nil
      if then_block
        processed.add(then_label)
        then_instrs = then_block.instructions.reject { |i| i.is_a?(WASM_GOTO) }
        goto_instr = then_block.instructions.find { |i| i.is_a?(WASM_GOTO) }
        then_next = goto_instr&.label
      end

      # Get else block
      else_block = block_map[else_label]
      else_instrs = []
      else_next = nil
      if else_block
        processed.add(else_label)
        else_instrs = else_block.instructions.reject { |i| i.is_a?(WASM_GOTO) }
        goto_instr = else_block.instructions.find { |i| i.is_a?(WASM_GOTO) }
        else_next = goto_instr&.label
      end

      # Build structured if-then-else:
      # test_instrs
      # (if (then
      #   then_instrs
      # ) (else
      #   else_instrs
      # ))
      structured_instrs = [
        *test_instrs,
        WASM.new("if"),
        *then_instrs,
        WASM.new("else"),
        *else_instrs,
        WASM.new("end"),
      ]

      # Determine merge point (where both branches go)
      merge_label = then_next || else_next

      WASM_STRUCTURED_BLOCK.new(test_label, structured_instrs, merge_label)
    end
  end
end

# Structured block that may have a continuation label
class WASM_STRUCTURED_BLOCK < Statement
  children :label, :instructions, :continuation_label
end
