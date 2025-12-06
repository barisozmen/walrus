# Pass execution helpers - convention over configuration
module Walrus
  module PassHelpers
    # Derive human-readable name from class: FoldConstants → "Fold Constants"
    def self.display_name(pass_class)
      pass_class.name.split('::').last
                .gsub(/([A-Z]+)([A-Z][a-z])/, '\1 \2')
                .gsub(/([a-z\d])([A-Z])/, '\1 \2')
    end

    # Run pass with context, handling special cases
    def self.run_with_context(pass, input, source = nil)
      case pass
      when Parser
        pass.run(input, source: source)
      when BraceCheck
        pass.source_lines = source.lines
        pass.run(input)
      else
        pass.run(input)
      end
    end
  end
end
