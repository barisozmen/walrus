# frozen_string_literal: true

require 'tty-spinner'
require 'tty-box'
require 'tty-table'
require_relative 'ui'
require_relative '../../compiler_error'

module Walrus
  class CliUI < UI
    def initialize(out: $stdout, err: $stderr, verbose: false)
      super(out: out, err: err)
      @verbose = verbose
    end

    def verbose? = @verbose

    def header(text)
      box = TTY::Box.frame(
        width: [text.size + 8, 60].min,
        height: 3,
        align: :center,
        border: :thick,
        style: { border: { fg: :bright_blue } }
      ) { pastel.decorate(text, :bold, :bright_white) }
      puts box
    end

    def section(text)
      puts
      puts pastel.decorate("== #{text} ", :bright_blue, :bold)
      puts
    end

    def warning(text)
      puts pastel.decorate("  !  #{text}", :yellow)
    end

    def debug(text)
      return unless verbose?
      puts pastel.decorate("  >  #{text}", :dim)
    end

    def file_info(label, path)
      size = File.exist?(path) ? File.size(path) : 0
      puts pastel.decorate("  [file] #{label}: ", :bright_white) +
           pastel.decorate(path, :bright_cyan) +
           pastel.decorate(" (#{format_bytes(size)})", :dim)
    end

    def command(text)
      puts pastel.decorate("  $ #{text}", :yellow, :bold)
    end

    def with_spinner(message, delay: 0.08, style: :pulse_2)
      spinner = TTY::Spinner.new(
        "[:spinner] #{pastel.decorate(message, :bright_white)}",
        format: style,
        interval: delay,
        success_mark: pastel.decorate('+', :green, :bold),
        error_mark: pastel.decorate('x', :red, :bold)
      )

      spinner.auto_spin
      start_time = Time.now

      begin
        result = yield spinner
        elapsed = ((Time.now - start_time) * 1000).round(1)
        spinner.success(pastel.decorate("(#{elapsed}ms)", :dim))
        result
      rescue CompilerError => e
        spinner.stop
        $stderr.puts "\n#{e.message}\n"
        raise
      rescue StandardError => e
        spinner.error(pastel.decorate("(failed)", :red))
        error("#{e.class}: #{e.message}")
        debug(e.backtrace.join("\n")) if verbose?
        raise
      end
    end

    def render_table(header:, rows:)
      table = TTY::Table.new(header, rows)
      puts table.render(:unicode, multiline: true, padding: [0, 2, 0, 2])
    end

    private

    def format_bytes(bytes)
      return "#{bytes} B" if bytes < 1024
      return "#{(bytes / 1024.0).round(1)} KB" if bytes < 1024 * 1024
      "#{(bytes / (1024.0 * 1024)).round(1)} MB"
    end
  end
end
