require_relative "../system_test"

# System test: gets must compile and run correctly with user input
class TestGets < SystemTest
  # Override to support stdin input
  def compile_and_run_with_input(fixture, input)
    source = File.join(self.class::FIXTURES, fixture)
    stdout, stderr, status = Open3.capture3("#{self.class::COMPILER} compile #{source} -o out.exe")
    assert status.success?, "Compilation failed:\n#{stderr}"

    stdout, stderr, status = Open3.capture3('./out.exe', stdin_data: input)
    assert status.success?, "Execution failed:\n#{stderr}"

    stdout
  ensure
    File.delete('out.exe') if File.exist?('out.exe')
    File.delete('out.ll') if File.exist?('out.ll')
  end

  def test_gets_simple
    output = compile_and_run_with_input('gets_simple.wl', "42\n")
    assert_equal "Out: 42\n", output
  end

  def test_gets_simple_negative
    output = compile_and_run_with_input('gets_simple.wl', "-17\n")
    assert_equal "Out: -17\n", output
  end

  def test_gets_interactive_calc
    output = compile_and_run_with_input('gets_interactive_calc.wl', "10\n20\n")
    expected = <<~OUT
      Out: 30
      Out: -10
      Out: 200
    OUT
    assert_equal expected, output
  end

  def test_gets_interactive_calc_larger_numbers
    output = compile_and_run_with_input('gets_interactive_calc.wl', "100\n50\n")
    expected = <<~OUT
      Out: 150
      Out: 50
      Out: 5000
    OUT
    assert_equal expected, output
  end
end
