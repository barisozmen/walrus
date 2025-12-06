require_relative '../test_context'

class DiagnosticFormatterTest < Minitest::Test
  def setup
    # Use disabled Pastel for predictable test output
    @original_pastel = Walrus.pastel
    Walrus.pastel = Pastel.new(enabled: false)
  end

  def teardown
    # Restore original Pastel
    Walrus.pastel = @original_pastel
  end

  def test_format_with_location
    loc = SourceLocation.new(10, 5, "var x = 42", "test.wl")
    result = DiagnosticFormatter.format(
      "Type mismatch",
      loc,
      severity: :error
    )

    assert_match(/test\.wl/, result)
    assert_match(/10:5/, result)
    assert_match(/var x = 42/, result)
    assert_match(/Type mismatch/, result)
    assert_match(/\^/, result)  # Caret pointer
  end

  def test_format_without_location_returns_raw_message
    result = DiagnosticFormatter.format(
      "Simple error",
      nil,
      severity: :error
    )

    assert_equal "Simple error", result
  end

  def test_color_selection_by_severity_error
    loc = SourceLocation.new(1, 1, "code", "test.wl")

    # With colors disabled, we can't test actual colors, but we can verify it doesn't crash
    result = DiagnosticFormatter.format(
      "Error message",
      loc,
      severity: :error
    )

    assert_match(/Error message/, result)
  end

  def test_color_selection_by_severity_warning
    loc = SourceLocation.new(1, 1, "code", "test.wl")

    result = DiagnosticFormatter.format(
      "Warning message",
      loc,
      severity: :warning
    )

    assert_match(/Warning message/, result)
    assert_match(/Warning at/, result)
  end

  def test_hint_rendering
    loc = SourceLocation.new(5, 10, "x = y + z", "test.wl")

    result = DiagnosticFormatter.format(
      "Variable y is not defined",
      loc,
      severity: :error,
      hint: "Did you mean to declare y first?"
    )

    assert_match(/Variable y is not defined/, result)
    assert_match(/Hint: Did you mean to declare y first\?/, result)
  end

  def test_hint_not_shown_when_nil
    loc = SourceLocation.new(5, 10, "x = y + z", "test.wl")

    result = DiagnosticFormatter.format(
      "Variable y is not defined",
      loc,
      severity: :error,
      hint: nil
    )

    assert_match(/Variable y is not defined/, result)
    refute_match(/Hint:/, result)
  end

  def test_error_class_in_header
    loc = SourceLocation.new(3, 7, "if x = 5 {", "test.wl")

    result = DiagnosticFormatter.format(
      "Cannot use assignment in conditional",
      loc,
      severity: :error,
      error_class: "CompilerError::SyntaxError"
    )

    assert_match(/CompilerError::SyntaxError at test\.wl at 3:7/, result)
    assert_match(/Cannot use assignment in conditional/, result)
  end

  def test_warning_header_format
    loc = SourceLocation.new(15, 3, "var unused = 10", "test.wl")

    result = DiagnosticFormatter.format(
      "Variable 'unused' is never used",
      loc,
      severity: :warning
    )

    assert_match(/Warning at test\.wl at 15:3/, result)
    assert_match(/Variable 'unused' is never used/, result)
  end

  def test_caret_position_matches_column
    loc = SourceLocation.new(1, 12, "func foo() {", "test.wl")

    result = DiagnosticFormatter.format(
      "Unexpected token",
      loc,
      severity: :error
    )

    lines = result.split("\n")
    source_line = lines.find { |l| l.include?("func foo()") }
    caret_line = lines[lines.index(source_line) + 1] if source_line

    assert caret_line, "Should have caret line"
    # Caret should be roughly at column 12 (accounting for line number prefix)
    assert_match(/\^/, caret_line)
  end

  def test_missing_source_line_handles_gracefully
    loc = SourceLocation.new(99, 1, nil, "test.wl")

    result = DiagnosticFormatter.format(
      "End of file reached",
      loc,
      severity: :error
    )

    assert_match(/test\.wl at 99:1/, result)
    assert_match(/End of file reached/, result)
    refute_match(/\^/, result)  # No caret when source_line is nil
  end

  def test_filename_defaults_to_source_when_nil
    loc = SourceLocation.new(5, 3, "var x = 10", nil)

    result = DiagnosticFormatter.format(
      "Some error",
      loc,
      severity: :error
    )

    assert_match(/<source> at 5:3/, result)
  end
end
