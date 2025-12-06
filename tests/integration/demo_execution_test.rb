require_relative "../test_context"

class DemoExecutionTest < Minitest::Test
  def test_all_demos_run_without_errors
    demo_files = Dir.glob(File.join(__dir__, "../../demo/*.rb"))

    demo_files.each do |demo|
      assert system("ruby", demo, out: File::NULL, err: File::NULL),
             "Demo failed: #{File.basename(demo)}"
    end
  end
end
