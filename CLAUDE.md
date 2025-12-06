# CLAUDE.md

Guidance for Claude Code when working with this codebase.

## Project Overview

Walrus: a compiler transforming `.wl` source into native executables via LLVM IR. Written in Ruby with metaprogramming, clean abstractions, and a polished CLI.

## Commands

```bash
# Compile
./bin/Walrus compile program.wl          # -> out.exe
./bin/Walrus compile program.wl -o name  # custom output
./bin/Walrus compile program.wl -v       # verbose with timing
./bin/Walrus compile program.wl -k       # keep LLVM IR

# Other
./bin/Walrus passes   # list all passes
./bin/Walrus version  # show version
rake test             # run all tests
```

## Architecture

### Pipeline (16 passes in `compile.rb`)

1. **Tokenization** - Lexical analysis
2. **Brace Check** - Validate balanced braces
3. **Parsing** - Build AST
4. **Constant Folding** - Optimize constants
5. **Variable Deinit** - Separate declarations from init
6. **Scope Resolution** - Local vs global
7. **Type Inference** - Infer and validate types, emit warnings
8. **Main Gathering** - Collect top-level into main()
9. **Return Injection** - Ensure explicit returns
10. **Lower Expressions** - Expressions → IR
11. **Lower Statements** - Statements → IR
12. **Basic Blocks** - Group into blocks
13. **Control Flow** - Flatten CFG
14. **LLVM Generation** - Generate LLVM IR
15. **LLVM Entry Blocks** - Add entry blocks
16. **LLVM Formatting** - Format IR
17. **Clang** - Link with runtime.c → executable

All passes implement `CompilerPass` (`compiler_passes/base.rb`).

### AST Transformer Pattern

Most passes inherit from `AstTransformerBasedCompilerPass`:

```ruby
class MyPass < AstTransformerBasedCompilerPass
  def before_transform(node, context)
    context.merge(label_gen: LabelGenerator.new)  # init state
  end

  def transform_binop(node, context)  # override per node type
    # return transformed node
  end

  def after_transform(node, result, context)
    result  # post-process
  end
end
```

Context = hash threading through traversal. Override `transform_<nodetype>` methods. Base handles recursion. See `docs/VISITOR_HOOKS_EXAMPLE.md`.

### Data Model (`model.rb`)

AST via metaprogramming:

```ruby
class BinOp < Expression
  children :op, :left, :right  # auto-generates initialize, ==, hash
end

node = BinOp.new('+', left, right)
```

Base classes: `Statement`, `Expression` (has `.type`), `INSTRUCTION`.

Types: `int`, `float`, `bool`, `char`. Inferred in pass 7.

### Error System (`compiler_error.rb`)

Rich errors with location tracking:
- `CompilerError::SyntaxError` - parsing phase
- `CompilerError::TypeError` - type checking
- `CompilerError::CodegenError` - LLVM generation
- `CompilerWarning` - unused vars, unreachable code, etc.

All display: filename, line/column, source line with caret, hint.

### Global Context (`Walrus.context`)

Shared hash across all passes:
- `:filename` - source filename for error reporting
- `:warnings` - array of `CompilerWarning` objects
- Used by Parser, BraceCheck for source line lookup

Reset via `Walrus.reset_context` before each compilation.

### Testing (57 files)

- `tests/unit/` - Individual pass tests
- `tests/integration/` - Multi-pass tests
- `tests/system/` - Full compilation
- `tests/fixtures/` - `.wl` programs
- `tests/helpers/` - AST diff, tree comparison

## Development

### Adding a Pass

1. Create `compiler_passes/XX_my_pass.rb`
2. Inherit from `CompilerPass` or `AstTransformerBasedCompilerPass`
3. Implement `run(input)`
4. Add to `PASSES` in `compile.rb`
5. Test in `tests/unit/test_my_pass.rb`

### Debugging

- `-v` - verbose with timing per pass
- `-k` - keep `out.ll` LLVM IR file
- `node.pretty_inspect` - visualize AST
- Run individual test files

### Style

- Passes are stateless (state in context hash)
- One transformation per pass
- Immutable transformations (new nodes, don't mutate)
- Case statements for node dispatch

## Structure

```
Walrus/
├── bin/Walrus              # CLI entry
├── compile.rb              # Thor CLI + pipeline (450 lines)
├── model.rb                # AST metaprogramming (670 lines)
├── compiler_error.rb       # Error/warning system (330 lines)
├── format.rb               # AST → source formatter
├── runtime.c               # C runtime (print functions)
├── compiler_passes/        # 18 pass files
│   ├── base.rb            # AstTransformer base class
│   └── 01..15_*.rb        # Individual passes
├── tests/                  # 57 test files
│   ├── unit/              # Per-pass tests
│   ├── integration/       # Multi-pass tests
│   ├── system/            # Full compilation
│   ├── fixtures/          # .wl programs
│   └── helpers/           # AST diff, reporters
├── pretty/                # AST printing
├── docs/                  # Architecture docs
└── Rakefile               # Test runner
```

## Key Files

- `compile.rb` - Thor CLI + CompilerPipeline (TTY ecosystem: spinners, tables, boxes)
- `model.rb` - AST with metaprogramming (`children` macro, `typed`)
- `compiler_error.rb` - Error/warning with SourceLocation
- `compiler_passes/base.rb` - CompilerPass + AstTransformerBasedCompilerPass
- `runtime.c` - `_print_int`, `_print_float`
- `format.rb` - AST → formatted source

## Walrus Language

```Walrus
// Variables
var x = 10;           // inferred type
var y float = 3.14;   // explicit type

// Functions
func add(a int, b int) int {
  return a + b;
}

// Control flow
if x < y { print x; }
while x > 0 { x = x - 1; }

// Operators: +, -, *, /, <, >, <=, >=, ==, !=, &&, ||, !, unary -
// Types: int, float, bool, char
// Built-in: print
```
