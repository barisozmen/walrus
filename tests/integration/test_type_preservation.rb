require_relative "../test_context"

class TestTypePreservation < Minitest::Test
  def test_types_preserved_through_compilation_pipeline
    source = <<~Walrus
      func add(a int, b int) int {
        var result int;
        result = a + b;
        return result;
      }
    Walrus

    # Collect types after parsing
    ast_after_parse = [Walrus::Tokenizer, Walrus::Parser].reduce(source) { |s, p| p.new.run(s) }
    types_after_parse = collect_types(ast_after_parse)

    # Run remaining passes
    remaining_passes = [
      Walrus::FoldConstants,
      Walrus::DeinitializeVariableDeclarations,
      Walrus::ResolveVariableScopes,
      Walrus::GatherTopLevelStatementsIntoMain,
      Walrus::EnsureAllFunctionsHaveExplicitReturns
    ]

    ast_final = remaining_passes.reduce(ast_after_parse) { |s, p| p.new.run(s) }
    types_final = collect_types(ast_final)

    # Verify all types from parse are preserved
    types_after_parse.each do |path, type|
      assert types_final.key?(path), "Node at #{path} disappeared"
      assert_equal type, types_final[path], "Type at #{path} changed from #{type} to #{types_final[path]}"
    end
  end

  private

  def collect_types(node, path = "root", types = {})
    return types if node.nil?

    if node.is_a?(Array)
      node.each_with_index { |n, i| collect_types(n, "#{path}[#{i}]", types) }
      return types
    end

    if node.respond_to?(:type) && node.type
      types[path] = node.type
    end

    return types unless node.respond_to?(:attr_names)

    node.attr_names.each do |attr|
      collect_types(node.instance_variable_get("@#{attr}"), "#{path}.#{attr}", types)
    end

    types
  end
end
