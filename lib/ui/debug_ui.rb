require 'tty-prompt'
require 'tty-spinner'
require 'tty-table'
require 'tty-box'
require 'tty-command'
require_relative 'ui'

module Walrus
  # Debug UI - development tools for AST visualization and diffs
  class DebugUI < UI
    attr_reader :prompt, :command

    def initialize(out: $stdout, err: $stderr)
      super
      @prompt = TTY::Prompt.new
      @command = TTY::Command.new(printer: :null)
    end

    def header(text)
      box = TTY::Box.frame(
        width: text.size + 8,
        height: 3,
        align: :center
      ) { pastel.decorate(text, :bold) }
      @out.puts box
    end

    def info_box(text)
      box = TTY::Box.frame(
        width: text.size + 20,
        padding: 1
      ) { pastel.decorate(text, :bright_blue) }
      @out.puts box
    end

    def with_spinner(message, delay: 0.08)
      spinner = TTY::Spinner.new("[:spinner] #{message}", format: :pulse_2, interval: delay)
      spinner.auto_spin
      begin
        result = yield spinner
        spinner.success("(done)")
        result
      rescue StandardError
        spinner.error("(failed)")
        raise
      end
    end

    def render_table(header:, rows:)
      table = TTY::Table.new(header, rows)
      @out.puts table.render(:unicode, multiline: true, padding: [0, 2, 0, 2])
    end

    def render_ast(node)
      require_relative '../../pretty/ast_printer'
      @out.puts AstPrinter.new(pastel).print(node)
    end

    def render_diff(expected, actual)
      require_relative '../../pretty/ast_printer'
      printer = AstPrinter.new(pastel)

      @out.puts pastel.red.bold("Expected:")
      @out.puts printer.print(expected)
      @out.puts
      @out.puts pastel.green.bold("Actual:")
      @out.puts printer.print(actual)
    end
  end
end
