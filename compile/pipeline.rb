# frozen_string_literal: true

require_relative 'pass_helpers'
require_relative 'context'
require_relative '../compiler_error'

module Walrus
  class CompilerPipeline
    PASSES = [
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
      FlattenControlFlow,
      GenerateLLVMCode,
      AddLlvmEntryBlocks,
      FormatLlvm
    ].freeze

    attr_reader :ui

    def initialize(ui:)
      @ui = ui
    end

    def compile(source:, output:, runtime:, optimize: '0')
      ui.header("Walrus Compiler")
      ui.info("Source: #{source.lines.count} lines")
      ui.info("Optimization: -O#{optimize}") if optimize != '0' && !optimize.empty?
      ui.info("Optimization: -O") if optimize.empty?

      start_time = Time.now
      result = source

      # Run compiler passes
      PASSES.each.with_index(1) do |pass_class, idx|
        pass_name = PassHelpers.display_name(pass_class)
        result = ui.with_spinner("Pass #{idx}/#{PASSES.size}: #{pass_name}") do
          PassHelpers.run_with_context(pass_class.new, result, source)
        end
        ui.debug("-> #{result.class} (#{result.to_s.bytesize}b)") if ui.verbose?
      end

      # Write LLVM IR
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
      ui.success("Compiled #{PASSES.size} passes in #{total_time}ms → #{output} (#{ui.send(:format_bytes, File.size(output))})")

      output
    rescue CompilerError => e
      # CompilerError already displayed in with_spinner rescue
      ui.error("Compilation failed")
      exit 1
    rescue StandardError => e
      ui.error("Compilation failed: #{e.message}")
      ui.debug(e.backtrace.join("\n")) if ui.verbose?
      raise
    end
  end
end
