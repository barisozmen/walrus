require_relative '../system_test'

class BreakContinueTest < SystemTest
  auto_test do |fixture, expected|
    output = compile_and_run(fixture)
    assert_equal expected, output
  end

  # Generate expected output for breakcontinue.wl
  def self.expected_output
    output = []

    # First loop: 0 through 10
    (0..10).each { |n| output << "Out: #{n}" }

    # Second loop: x*y for x,y in 0..9
    (0..9).each do |x|
      (0..9).each do |y|
        output << "Out: #{x * y}"
      end
    end

    output.join("\n") + "\n"
  end

  # Generate expected output for break_early.wl
  def self.break_early_output
    output = []
    output << "Out: 0"  # prints i (which is 0)
    output << "Out: 1"  # prints found (which is 1 after break)
    output.join("\n") + "\n"
  end

  # Generate expected output for continue_skip_evens.wl
  def self.continue_skip_evens_output
    output = []
    # Only odd numbers from 1 to 9
    [1, 3, 5, 7, 9].each { |n| output << "Out: #{n}" }
    output.join("\n") + "\n"
  end

  # Generate expected output for breakcontinue_in_highly_nested_loops.wl
  def self.highly_nested_output
    output = []
    # 5 nested loops: a(0-1), b(0-1), c(0-1), d(0-1), e(0,1,2)
    # Prints position as: a*10000 + b*1000 + c*100 + d*10 + e
    (0..1).each do |a|
      (0..1).each do |b|
        (0..1).each do |c|
          (0..1).each do |d|
            # e prints 0, 1, 2 (continue skips incrementing after 1, break exits at 2)
            (0..2).each do |e|
              pos = a * 10000 + b * 1000 + c * 100 + d * 10 + e
              output << "Out: #{pos}"
            end
          end
        end
      end
    end
    output.join("\n") + "\n"
  end

  TESTCASES = {
    'breakcontinue.wl' => expected_output,
    'break_early.wl' => break_early_output,
    'continue_skip_evens.wl' => continue_skip_evens_output,
    'breakcontinue_in_highly_nested_loops.wl' => highly_nested_output
  }

  generate_tests
end
