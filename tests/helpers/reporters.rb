require 'minitest/reporters'

Minitest::Reporters.use! [
  Minitest::Reporters::SpecReporter.new(
    color: true,
    slow_count: 5,
    detailed_skip: false
  )
]
