#!/usr/bin/env ruby
# Quick test script to identify failing fixtures

require_relative 'model'
require_relative 'compiler_error'
require_relative 'compile/context'
require_relative 'compile/pass_helpers'

# Load all compiler passes
Dir.glob(File.join(__dir__, 'compiler_passes', '*.rb')).each { |f| require f }
require_relative 'compile/pipeline'
require_relative 'lib/ui/ui'

# Get all non-error fixtures
FIXTURES_DIR = File.join(__dir__, 'tests', 'fixtures')
fixtures = Dir.glob(File.join(FIXTURES_DIR, '*.wl')).select do |f|
  basename = File.basename(f)
  !basename.start_with?('error_') &&
  !basename.include?('gets_') &&  # Skip interactive
  !basename.include?('string_') &&  # Skip strings (not implemented)
  !basename.include?('game_of_life') &&  # Skip very complex
  !basename.include?('mandel') &&
  !basename.include?('julia')
end

puts "Testing #{fixtures.size} fixtures with JVM backend..."
puts

compiled = []
failed = []

fixtures.each do |fixture_path|
  fixture_name = File.basename(fixture_path)
  print "#{fixture_name.ljust(50)} ... "

  begin
    source = File.read(fixture_path)

    Walrus.reset_context
    Walrus.context[:filename] = fixture_name
    Walrus.context[:warnings] = []

    ui = Walrus::UI.new(verbose: false)
    pipeline = Walrus::CompilerPipeline.new(ui: ui)

    output = "/tmp/#{fixture_name.sub('.wl', '.exe')}"

    result = pipeline.compile(
      source: source,
      output: output,
      runtime: nil,
      target: 'jvm'
    )

    puts "✓ OK"
    compiled << fixture_name
  rescue => e
    puts "✗ FAIL: #{e.class.name}"
    failed << { name: fixture_name, error: e }
  end
end

puts
puts "=" * 70
puts "SUMMARY:"
puts "  Total: #{fixtures.size}"
puts "  Compiled: #{compiled.size} (#{(compiled.size.to_f / fixtures.size * 100).round}%)"
puts "  Failed: #{failed.size}"
puts

if failed.any?
  puts "FAILED FIXTURES:"
  failed.each do |f|
    puts
    puts "  #{f[:name]}"
    puts "    Error: #{f[:error].class.name}"
    puts "    Message: #{f[:error].message[0..200]}"
    if f[:error].respond_to?(:backtrace)
      relevant = f[:error].backtrace.select { |l| l.include?('walrus') }.first(3)
      relevant.each { |l| puts "      #{l}" }
    end
  end
end
