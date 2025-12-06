require "minitest/autorun"
require "debug"

require_relative "helpers/reporters"
require_relative "helpers/ast_diff"

require_relative "../model"
require_relative "../format"
require_relative "../compile"

class Minitest::Test
  def self.auto_test(&block)
    @auto_test_block = block
  end

  def self.generate_tests
    return unless const_defined?(:TESTCASES, false)

    const_get(:TESTCASES).each_with_index do |(input, expected), i|
      define_method("test_testcase_#{i}") do
        instance_exec(input, expected, &self.class.instance_variable_get(:@auto_test_block))
      end
    end
  end
end
