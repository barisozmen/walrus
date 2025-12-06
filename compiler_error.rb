# compiler_error.rb
#
# Rich error reporting for the Walrus compiler
# Single source of truth for all compiler errors

require 'pastel'

# Walrus module is defined here for Pastel singleton
# and extended in compile.rb for context management.
# Ruby allows module reopening - this avoids circular dependencies.
module Walrus
  def self.pastel
    @pastel ||= Pastel.new
  end

  def self.pastel=(instance)
    @pastel = instance
  end

  # For test isolation: reset Pastel instance
  def self.reset_pastel
    @pastel = nil
  end
end

# DiagnosticFormatter - Single Source of Truth for error/warning display
module DiagnosticFormatter
  def self.format(raw_message, loc, severity:, hint: nil, error_class: nil)
    return raw_message unless loc

    pastel = Walrus.pastel
    lines = []

    # Header
    filename = loc.filename || '<source>'
    severity_color = severity_color_for(severity)
    header_text = header_for(severity, filename, loc, error_class)
    lines << pastel.decorate(header_text, severity_color, :bold)
    lines << ""

    # Source line with caret
    if loc.source_line
      lineno_str = "#{loc.lineno} | "
      lines << pastel.dim(lineno_str) + loc.source_line

      padding = " " * (lineno_str.length + loc.column - 1)
      lines << pastel.decorate(padding + "^", severity_color, :bold)
    end

    lines << ""
    lines << raw_message

    # Hint (if provided)
    if hint
      lines << ""
      lines << pastel.dim("Hint: #{hint}")
    end

    lines.join("\n")
  end

  private

  def self.severity_color_for(severity)
    case severity
    when :error then :red
    when :warning then :yellow
    else :red
    end
  end

  def self.header_for(severity, filename, loc, error_class)
    if error_class
      "#{error_class} at #{filename} at #{loc.lineno}:#{loc.column}"
    elsif severity == :warning
      "Warning at #{filename} at #{loc.lineno}:#{loc.column}"
    else
      "Error at #{filename} at #{loc.lineno}:#{loc.column}"
    end
  end
end

class CompilerError < StandardError
  attr_reader :loc, :phase, :severity

  def initialize(message, loc, phase:, severity: :error, hint: nil)
    @raw_message = message
    @loc = loc
    @phase = phase
    @severity = severity
    @hint = hint
    super(display)
  end

  def display
    DiagnosticFormatter.format(
      @raw_message,
      @loc,
      severity: @severity,
      hint: @hint,
      error_class: self.class.name
    )
  end

end

# Subclasses for different compilation phases

class CompilerError::SyntaxError < CompilerError
  def initialize(message, loc, hint: nil)
    super(message, loc, phase: :syntactic, hint: hint)
  end
end

class CompilerError::TypeError < CompilerError
  def initialize(message, loc, hint: nil)
    super(message, loc, phase: :semantic, hint: hint)
  end
end

class CompilerError::CodegenError < CompilerError
  def initialize(message, loc, hint: nil)
    super(message, loc, phase: :codegen, hint: hint)
  end
end

# ---------------------------------------------------------------------------
# Compiler Warning System
# ---------------------------------------------------------------------------

class CompilerWarning
  attr_reader :message, :loc, :phase

  def initialize(message, loc, phase:, hint: nil)
    @raw_message = message
    @loc = loc
    @phase = phase
    @hint = hint
  end

  def message
    display
  end

  def display
    DiagnosticFormatter.format(
      @raw_message,
      @loc,
      severity: :warning,
      hint: @hint
    )
  end
end
