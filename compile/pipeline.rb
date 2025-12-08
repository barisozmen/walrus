# frozen_string_literal: true

require_relative 'pass_helpers'
require_relative 'context'
require_relative '../compiler_error'

module Walrus
  class CompilerPipeline
    # Shared frontend and middle-end passes (target-independent)
    # These produce a target-independent IR with abstract instructions
    SHARED_PASSES = [
      Tokenizer,
      BraceCheck,
      Parser,
      LowerCaseToElsIf,
      LowerElsIfToIf,
      LowerForLoopsToWhileLoops,
      LowerShortCircuitOperators,
      FoldConstants,
      DeinitializeVariableDeclarations,
      ResolveVariableScopes,
      InferAndCheckTypes,
      DetectUnusedVars,
      GatherTopLevelStatementsIntoMain,
      EnsureAllFunctionsHaveExplicitReturns,
      LowerExpressionsToInstructions,
      LowerStatementsToInstructions,
      MergeStatementsIntoBasicBlocks,
      FlattenControlFlow
    ].freeze

    # LLVM backend passes
    LLVM_PASSES = [
      GenerateLLVMCode,
      AddLlvmEntryBlocks,
      FormatLlvm
    ].freeze

    # WasmGC backend passes
    WASMGC_PASSES = [
      GenerateWasmGCCode,
      StructureWasmControlFlow,
      FormatWasmGC
    ].freeze

    # All passes for LLVM target (default) - for backwards compatibility
    PASSES = (SHARED_PASSES + LLVM_PASSES).freeze

    # Supported compilation targets
    TARGETS = {
      'llvm' => { passes: LLVM_PASSES, extension: '.ll', description: 'LLVM IR (native executable)' },
      'wasm-gc' => { passes: WASMGC_PASSES, extension: '.wat', description: 'WebAssembly with GC (WAT format)' }
    }.freeze

    attr_reader :ui

    def initialize(ui:)
      @ui = ui
    end

    def compile(source:, output:, runtime:, optimize: '0', target: 'llvm')
      target_info = TARGETS[target]
      raise ArgumentError, "Unknown target: #{target}. Available: #{TARGETS.keys.join(', ')}" unless target_info

      backend_passes = target_info[:passes]
      all_passes = SHARED_PASSES + backend_passes

      ui.header("Walrus Compiler")
      ui.info("Target: #{target} (#{target_info[:description]})")
      ui.info("Source: #{source.lines.count} lines")
      if target == 'llvm'
        ui.info("Optimization: -O#{optimize}") if optimize != '0' && !optimize.empty?
        ui.info("Optimization: -O") if optimize.empty?
      end

      start_time = Time.now
      result = source

      # Run compiler passes
      all_passes.each.with_index(1) do |pass_class, idx|
        pass_name = PassHelpers.display_name(pass_class)
        result = ui.with_spinner("Pass #{idx}/#{all_passes.size}: #{pass_name}") do
          PassHelpers.run_with_context(pass_class.new, result, source)
        end
        ui.debug("-> #{result.class} (#{result.to_s.bytesize}b)") if ui.verbose?
      end

      # Target-specific output handling
      case target
      when 'llvm'
        compile_llvm(result, output, runtime, optimize)
      when 'wasm-gc'
        compile_wasmgc(result, output)
      end

      # Show warnings
      warnings = Walrus.context[:warnings] || []
      if warnings.any?
        ui.section("Warnings")
        warnings.each { |w| puts w.display; puts }
      end

      # Done
      ui.section("Success!")
      total_time = ((Time.now - start_time) * 1000).round(1)
      ui.success("Compilation completed successfully")

      output_file = target == 'llvm' ? output : output.sub(/\.(exe|out)$/, '') + '.wat'
      file_size = File.exist?(output_file) ? File.size(output_file) : 0
      ui.success("Compiled #{all_passes.size} passes in #{total_time}ms → #{output_file} (#{ui.send(:format_bytes, file_size)})")

      output_file
    rescue CompilerError => e
      # CompilerError already displayed in with_spinner rescue
      ui.error("Compilation failed")
      exit 1
    rescue StandardError => e
      ui.error("Compilation failed: #{e.message}")
      ui.debug(e.backtrace.join("\n")) if ui.verbose?
      raise
    end

    private

    # LLVM compilation: write IR and link with clang
    def compile_llvm(result, output, runtime, optimize)
      llvm_file = output.sub(/\.(exe|out)$/, '') + '.ll'
      File.write(llvm_file, result)
      ui.file_info("LLVM IR", llvm_file)

      # Compile with clang
      opt_flag = case optimize
                 when '0' then ''
                 when '' then ' -O'
                 else " -O#{optimize}"
                 end
      compile_cmd = "clang#{opt_flag} #{llvm_file} #{runtime} -o #{output}"
      ui.command(compile_cmd)

      ui.with_spinner("Linking with clang") do
        raise "Clang compilation failed. Run with -v for details." unless system(compile_cmd, out: File::NULL, err: File::NULL)
      end
    end

    # WasmGC compilation: write WAT file
    def compile_wasmgc(result, output)
      wat_file = output.sub(/\.(exe|out)$/, '') + '.wat'
      File.write(wat_file, result)
      ui.file_info("WebAssembly Text", wat_file)

      # Optionally compile to binary .wasm if wat2wasm is available
      wasm_file = wat_file.sub('.wat', '.wasm')
      if system('which wat2wasm > /dev/null 2>&1')
        compile_cmd = "wat2wasm #{wat_file} -o #{wasm_file}"
        ui.command(compile_cmd)

        ui.with_spinner("Assembling to binary WASM") do
          unless system(compile_cmd, out: File::NULL, err: File::NULL)
            ui.warn("wat2wasm failed - WAT file still available")
          end
        end

        ui.file_info("WebAssembly Binary", wasm_file) if File.exist?(wasm_file)
      else
        ui.info("Tip: Install wabt (wat2wasm) to compile WAT to binary WASM")
      end

      ui.info("Run with: node misc/wasm_loader.js #{wat_file}")
    end
  end
end
