# Walrus Pretty Printer

Beautiful, colorful AST visualization for the Walrus compiler.

## Usage

### CLI Tool

```bash
# Show parsed AST as a tree
./bin/wab show wab/test/fixtures/fact.wl --raw

# Format Walrus source code
./bin/wab format wab/demo.wl

# See all commands
./bin/wab help
```

### In Tests

Test failures automatically show beautiful tree diffs:

```ruby
assert_equal expected_ast, actual_ast
```

Output shows colored, indented trees instead of single-line inspect strings.

### Programmatic

```ruby
# Pretty print any AST node
require_relative 'wab/model'
require_relative 'wab/pretty/ast_printer'

node = IntegerLiteral.new(42)
puts node.pretty_inspect

# Or use the UI class
require_relative 'wab/pretty/ui'

ui = Walrus::UI.new
ui.render_ast(program)
ui.render_diff(expected, actual)
```

## Features

- **Tree visualization** using tty-tree
- **Color coding** by node type (statements, expressions, literals)
- **Automatic test diffs** in Minitest
- **CLI commands** for inspecting AST
- **Spinner animations** for long operations
- **Formatted boxes** for headers
