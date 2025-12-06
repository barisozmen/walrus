require 'thor'
require_relative 'ui'
require_relative '../compile'
require_relative '../format'

module Walrus
  class CLI < Thor
    desc "show FILE", "Pretty-print AST from Walrus source file"
    option :raw, type: :boolean, default: false, desc: "Show raw parsed AST without compilation passes"
    def show(file)
      ui = UI.new

      unless File.exist?(file)
        ui.error "File not found: #{file}"
        exit 1
      end

      source = File.read(file)

      begin
        if options[:raw]
          ui.with_spinner("Parsing #{file}...") do
            tokens = Walrus::Tokenizer.new.run(source)
            @result = Walrus::Parser.new.run(tokens)
          end
        else
          ui.with_spinner("Compiling #{file}...") do
            @result = compile(source)
          end
        end

        ui.header "AST for #{file}"
        ui.render_ast(@result)
      rescue => e
        ui.error "Failed: #{e.message}"
        puts e.backtrace.first(5)
        exit 1
      end
    end

    desc "format FILE", "Format and print Walrus source code"
    def format(file)
      ui = UI.new

      unless File.exist?(file)
        ui.error "File not found: #{file}"
        exit 1
      end

      source = File.read(file)

      begin
        ui.with_spinner("Formatting #{file}...") do
          tokens = Walrus::Tokenizer.new.run(source)
          ast = Walrus::Parser.new.run(tokens)
          @formatted = format_program(ast)
        end

        ui.success "Formatted code:"
        puts @formatted
      rescue => e
        ui.error "Failed: #{e.message}"
        exit 1
      end
    end
  end
end
