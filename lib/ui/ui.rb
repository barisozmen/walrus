# Base UI - shared display primitives
module Walrus
  class UI
    attr_reader :pastel

    def initialize(out: $stdout, err: $stderr, verbose: false)
      @pastel = Walrus.pastel
      @out = out
      @err = err
      @verbose = verbose
    end

    def verbose?
      @verbose
    end

    def info(text)
      @out.puts @pastel.decorate("  i  #{text}", :cyan)
    end

    def success(text)
      @out.puts @pastel.decorate("  +  #{text}", :green, :bold)
    end

    def error(text)
      @err.puts @pastel.decorate("  x  #{text}", :red, :bold)
    end

    def debug(text)
      @out.puts @pastel.decorate("  d  #{text}", :dim) if verbose?
    end

    def header(text)
      @out.puts @pastel.decorate("=== #{text} ===", :bold)
    end

    def with_spinner(message, **_options)
      # Simple no-op version for testing - just yield without spinner
      yield if block_given?
    end
  end
end
