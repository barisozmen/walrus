# frozen_string_literal: true

require_relative 'pass_helpers'
require_relative 'context'
require_relative '../compiler_error'

module Walrus
  class CompilerPipeline
    # Shared frontend passes (backend-agnostic)
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

    # LLVM-specific backend
    LLVM_PASSES = [
      GenerateLLVMCode,
      AddLlvmEntryBlocks,
      FormatLlvm
    ].freeze

    # JVM-specific backend
    JVM_PASSES = [
      AllocateJVMLocalVariables,
      GenerateJVMBytecode,
      FormatJVMClass
    ].freeze

    # Legacy constant for backward compatibility
    PASSES = (SHARED_PASSES + LLVM_PASSES).freeze

    attr_reader :ui

    def initialize(ui:)
      @ui = ui
    end

    def compile(source:, output:, runtime:, optimize: '0', target: 'llvm')
      # Select backend passes based on target
      backend_passes = case target
                       when 'jvm' then JVM_PASSES
                       when 'llvm' then LLVM_PASSES
                       else raise "Unknown target: #{target}"
                       end

      passes = SHARED_PASSES + backend_passes

      ui.header("Walrus Compiler (#{target.upcase} target)")
      ui.info("Source: #{source.lines.count} lines")
      ui.info("Target: #{target}")
      ui.info("Optimization: -O#{optimize}") if optimize != '0' && !optimize.empty?
      ui.info("Optimization: -O") if optimize.empty?

      start_time = Time.now
      result = source

      # Run compiler passes
      passes.each.with_index(1) do |pass_class, idx|
        pass_name = PassHelpers.display_name(pass_class)
        result = ui.with_spinner("Pass #{idx}/#{passes.size}: #{pass_name}") do
          PassHelpers.run_with_context(pass_class.new, result, source)
        end
        ui.debug("-> #{result.class} (#{result.to_s.bytesize}b)") if ui.verbose?
      end

      # Target-specific output
      case target
      when 'llvm'
        compile_llvm(result, output, runtime, optimize)
      when 'jvm'
        compile_jvm(result, output)
      end

      # Show warnings
      display_warnings

      # Done
      ui.section("Success!")
      total_time = ((Time.now - start_time) * 1000).round(1)
      ui.success("Compilation completed successfully")
      ui.success("Compiled #{passes.size} passes in #{total_time}ms → #{output}")

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

    private

    def compile_llvm(llvm_ir, output, runtime, optimize)
      # Write LLVM IR
      llvm_file = output.sub(/\.(exe|out)$/, '') + '.ll'
      File.write(llvm_file, llvm_ir)
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

      ui.file_info("Executable", output)
    end

    def compile_jvm(class_bytes, output)
      # Write .class file
      # Java requires the file name to match the class name
      class_name = Walrus.context[:class_name] || 'WalrusProgram'
      output_dir = File.dirname(output)
      class_file = File.join(output_dir, "#{class_name}.class")

      File.binwrite(class_file, class_bytes)
      ui.file_info("JVM Class", class_file)

      # Create executable wrapper script
      write_java_launcher(class_file, output)
    end

    def write_java_launcher(class_file, output)
      # All Walrus programs compile to WalrusProgram class
      class_name = Walrus.context[:class_name] || 'WalrusProgram'
      class_dir = File.dirname(class_file)

      launcher = <<~BASH
        #!/usr/bin/env bash
        # Walrus JVM launcher
        # Runs the compiled JVM class file
        exec java -cp "#{class_dir}" #{class_name} "$@"
      BASH

      File.write(output, launcher)
      File.chmod(0755, output)
      ui.file_info("Launcher", output)
    end

    def display_warnings
      warnings = Walrus.context[:warnings] || []
      return unless warnings.any?

      ui.section("Warnings")
      warnings.each { |w| puts w.display; puts }
    end
  end
end
