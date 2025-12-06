require_relative "../system_test"

# System test: string type support
class TestStrings < SystemTest
  auto_test do |fixture, expected|
    output = compile_and_run(fixture)
    assert_equal expected, output
  end

  TESTCASES = {
    'string_hello.wl' => <<~OUT,
      Out: Hello, World!
    OUT

    'string_multiple.wl' => <<~OUT,
      Out: Hello, Walrus!
      Out: Strings work!

      Out: She said "Hi"
      Out: Direct string literal
    OUT

    'string_escapes.wl' => <<~OUT
      Out: Tab:\there
      Out: Newline:
      here
      Out: Quote:"here"
    OUT
  }

  generate_tests
end
