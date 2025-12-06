require 'pastel'

# PastelHelpers - Test isolation for Walrus.pastel singleton
#
# Provides helper methods to manage the global Pastel instance during tests,
# ensuring tests don't interfere with each other due to shared state.
#
# Usage:
#   class MyTest < Minitest::Test
#     include PastelHelpers
#
#     def test_with_disabled_colors
#       with_disabled_colors do
#         # Code here runs with colors disabled
#         result = DiagnosticFormatter.format(...)
#         assert_match(/expected/, result)
#       end
#     end
#   end
module PastelHelpers
  # Run a block with colors disabled, then restore original Pastel
  def with_disabled_colors
    original = Walrus.pastel
    Walrus.pastel = Pastel.new(enabled: false)
    yield
  ensure
    Walrus.pastel = original
  end

  # Run a block with a custom Pastel instance
  def with_pastel(pastel_instance)
    original = Walrus.pastel
    Walrus.pastel = pastel_instance
    yield
  ensure
    Walrus.pastel = original
  end

  # Reset Pastel to a fresh instance (useful in setup/teardown)
  def reset_pastel
    Walrus.reset_pastel
  end
end
