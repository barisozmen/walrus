#!/usr/bin/env ruby
# frozen_string_literal: true

require 'thor'
require 'tty-prompt'
require 'tty-spinner'
require 'tty-table'
require 'tty-box'
require 'tty-command'
require 'tty-logger'
require 'tty-tree'
require 'pastel'
require 'fileutils'

# Load compiler dependencies
require_relative 'model'
require_relative 'compiler_error'
require_relative 'format'
require_relative 'compile/context'
require_relative 'lib/ui/ui'
require_relative 'lib/ui/cli_ui'
require_relative 'compile/pass_helpers'
Dir.glob(File.join(__dir__, 'compiler_passes', '*.rb')).each do |file|
  require file
end
require_relative 'compile/pipeline'
require_relative 'compile/ast_printer'

module Walrus
  class CLI < Thor
    class_option :verbose,
                 aliases: '-v',
                 type: :boolean,
                 default: false,
                 desc: 'Print detailed compilation steps (like scalac -verbose)'

    desc 'compile INPUT', 'Compile a Walrus source file'
    long_desc <<~DESC
      Compile a Walrus source file to a native executable.

      Examples:
        $ wab compile input.wab
        $ wab compile input.wab -o myprogram
        $ wab compile input.wab -o myprogram --runtime custom_runtime.c
        $ wab compile input.wab -v
        $ wab compile input.wab -r           # Compile and run immediately
        $ wab compile input.wab -O 2         # Optimize for performance
        $ wab compile input.wab --optimize s # Optimize for size

      Optimization levels:
        -O0: No optimization (default, fastest compilation, best debugging)
        -O1: Basic optimizations
        -O2: Recommended for most cases (moderate optimizations)
        -O3: Aggressive optimizations (may increase binary size)
        -Ofast: Like -O3 but may violate language standards (fastest)
        -Os: Optimize for size
        -Oz: Aggressive size optimization
        -Og: Good for debugging while optimizing

      Note: Both executable (.exe) and LLVM IR (.ll) files are always generated.
    DESC

    option :output,
           aliases: '-o',
           type: :string,
           desc: 'Output executable name (default: out.exe)'

    option :runtime,
           type: :string,
           desc: 'Path to runtime.c (default: Walrus/misc/runtime.c)'

    option :optimize,
           aliases: '-O',
           type: :string,
           default: '0',
           lazy_default: '',
           desc: 'Optimization level: (none), 0, 1, 2, 3, fast, s, z, g (default: 0)'

    option :run,
           aliases: '-r',
           type: :boolean,
           default: false,
           desc: 'Run the executable after compilation'

    option :target,
           aliases: '-t',
           type: :string,
           default: 'llvm',
           desc: 'Compilation target: llvm or jvm (default: llvm)'

    def compile(input)
      # Validate input
      unless File.exist?(input)
        ui.error("Input file not found: #{input}")
        exit 1
      end

      # Validate target
      target = options[:target]
      unless %w[llvm jvm].include?(target)
        ui.error("Invalid target: #{target}. Must be 'llvm' or 'jvm'")
        exit 1
      end

      # Set defaults
      output = options[:output] || "sandbox/#{File.basename(input, '.*')}.exe"
      runtime = options[:runtime] || File.join(File.dirname(__FILE__), 'misc/runtime.c')

      # Ensure sandbox directory exists
      FileUtils.mkdir_p('sandbox')

      # Only check runtime for LLVM target
      if target == 'llvm'
        unless File.exist?(runtime)
          ui.error("Runtime not found: #{runtime}")
          exit 1
        end
      end

      # Read source
      source = File.read(input)

      # Set global context
      Walrus.reset_context
      Walrus.context[:filename] = File.basename(input)
      Walrus.context[:warnings] = []

      # Compile
      pipeline = CompilerPipeline.new(ui: ui)
      begin
        result = pipeline.compile(
          source: source,
          output: output,
          runtime: runtime,
          optimize: options[:optimize],
          target: target
        )

        if options[:run]
          ui.success("Running ./#{result}")
          puts "" # Add blank line for separation
          system("./#{result}")
        else
          ui.success("Run with: ./#{result}")
        end
      rescue StandardError
        ui.error("Compilation failed")
        exit 1
      end
    end

    desc 'version', 'Show Walrus compiler version'
    def version
      ui.info("Walrus Compiler v0.1.0")
      ui.info("A modern compiler for the Walrus programming language")
    end

    desc 'passes', 'List all compiler passes'
    def passes
      ui.header("Walrus Compiler Passes")
      CompilerPipeline::PASSES.each.with_index(1) do |pass_class, idx|
        ui.info("#{idx}. #{PassHelpers.display_name(pass_class)}")
      end
    end

    desc 'show FILE', 'Pretty-print AST from Walrus source file'
    option :raw, type: :boolean, default: false, desc: 'Show raw parsed AST without compilation passes'
    def show(file)
      unless File.exist?(file)
        ui.error("File not found: #{file}")
        exit 1
      end

      source = File.read(file)

      begin
        result = if options[:raw]
          ui.with_spinner("Parsing #{file}...") do
            tokens = Tokenizer.new.run(source)
            Parser.new.run(tokens)
          end
        else
          ui.with_spinner("Compiling #{file}...") do
            run_pipeline_without_codegen(source)
          end
        end

        ui.header("AST for #{file}")
        puts AstPrinter.new(pastel).print(result)
      rescue StandardError => e
        ui.error("Failed: #{e.message}")
        puts e.backtrace.first(5) if options[:verbose]
        exit 1
      end
    end

    desc 'format FILE', 'Format and print Walrus source code'
    def format(file)
      unless File.exist?(file)
        ui.error("File not found: #{file}")
        exit 1
      end

      source = File.read(file)

      begin
        formatted = ui.with_spinner("Formatting #{file}...") do
          tokens = Tokenizer.new.run(source)
          ast = Parser.new.run(tokens)
          Formatter.new.format_program(ast)
        end

        ui.success("Formatted code:")
        puts formatted
      rescue StandardError => e
        ui.error("Failed: #{e.message}")
        exit 1
      end
    end

    default_task :compile

    private

    def ui
      @ui ||= CliUI.new(verbose: options[:verbose])
    end

    def pastel
      @pastel ||= Pastel.new
    end

    def run_pipeline_without_codegen(source)
      result = source
      # Run all passes except code generation
      passes = CompilerPipeline::PASSES.take_while { |p| p != GenerateLLVMCode }
      passes.each do |pass_class|
        result = PassHelpers.run_with_context(pass_class.new, result, source)
      end
      result
    end
  end
end

# Run CLI if this file is executed directly
if __FILE__ == $PROGRAM_NAME
  Walrus::CLI.start(ARGV)
end
