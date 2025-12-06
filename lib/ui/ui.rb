# Base UI - shared display primitives
module Walrus
  class UI
    attr_reader :pastel

    def initialize(out: $stdout, err: $stderr)
      @pastel = Walrus.pastel
      @out = out
      @err = err
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
  end
end
