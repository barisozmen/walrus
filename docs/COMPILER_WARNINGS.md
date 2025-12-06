# Compiler Warning System

## Overview

The Walrus compiler includes a comprehensive warning system that helps catch potential issues without stopping compilation. Warnings are non-fatal diagnostics that highlight code smells, unused code, and potentially problematic patterns.

## Architecture

### Warning Collection

Warnings are collected in the global compilation context:

```ruby
Walrus.context[:warnings] = []
```

Any compiler pass can emit warnings:

```ruby
Walrus.context[:warnings] << CompilerWarning.unused_variable(
  name: 'x',
  loc: node.loc
)
```

### Display Flow

1. **During compilation**: Passes collect warnings silently
2. **After success**: All warnings displayed together before summary
3. **On error**: Warnings are not displayed (error takes precedence)

### Warning vs Error

| Feature | Error | Warning |
|---------|-------|---------|
| Fatal | Yes - stops compilation | No - compilation continues |
| Color | Red | Yellow |
| Collection | Raised immediately | Collected in context |
| Display | During pass execution | After all passes succeed |

## Warning Types

### Unused Variable (W001)

**Trigger**: Variable declared but never referenced

```Walrus
var x int = 10;  // Warning: Unused variable 'x'
var y int = 20;
print y;
```

**Rationale**: Unused variables clutter code and may indicate logic errors.

### Unreachable Code (W002)

**Trigger**: Statements after `return`, `break`, or `continue`

```Walrus
func foo() int {
  return 42;
  print 99;  // Warning: Unreachable code detected
}
```

**Rationale**: Unreachable code never executes and indicates dead logic.

### Integer Division Truncation (W003) [Future]

**Trigger**: Division of two integers results in truncation

```Walrus
var x int = 5 / 2;  // Warning: Integer division truncates (result: 2, not 2.5)
```

### Shadowed Variable (W004) [Future]

**Trigger**: Local variable shadows outer scope variable

```Walrus
var x int = 10;
func foo() {
  var x int = 20;  // Warning: Variable 'x' shadows outer scope
}
```

## Implementation Guide

### Adding a New Warning Type

**Step 1: Add helper method to CompilerWarning**

```ruby
# compiler_error.rb
class CompilerWarning
  def self.your_warning_type(param:, loc:)
    new(
      "Warning message with #{param}",
      loc,
      phase: :semantic  # or :syntactic, :codegen
    )
  end
end
```

**Step 2: Emit warning in compiler pass**

```ruby
# In your compiler pass
def transform_somenode(node, context)
  if should_warn?(node)
    Walrus.context[:warnings] << CompilerWarning.your_warning_type(
      param: node.value,
      loc: node.loc
    )
  end
  # Continue transformation
  node
end
```

**Step 3: Add test case**

```ruby
# tests/unit/test_warnings.rb
def test_your_warning_type
  source = <<~WB
    // Code that triggers warning
  WB

  warnings = compile_and_get_warnings(source)
  assert_equal 1, warnings.size
  assert_match /Warning message/, warnings.first.message
end
```

## Usage Examples

### Example 1: Clean Code (No Warnings)

```Walrus
var x int = 10;
var y int = 20;
print x + y;
```

**Output:**
```
✓ Compilation completed successfully
```

### Example 2: Unused Variable Warning

```Walrus
var unused int = 42;
var used int = 10;
print used;
```

**Output:**
```
⚠ Warning at program.wl at 1:5

1 | var unused int = 42;
        ^

Unused variable 'unused'

✓ Compilation completed successfully
```

### Example 3: Multiple Warnings

```Walrus
var a int = 1;
var b int = 2;
var c int = 3;
print c;
```

**Output:**
```
== Warnings

⚠ Warning at program.wl at 1:5
Unused variable 'a'

⚠ Warning at program.wl at 2:5
Unused variable 'b'

== Success!
✓ Compilation completed successfully
```

## Future Enhancements

### Strict Mode

Convert warnings to errors:

```bash
./bin/Walrus compile program.wl --strict
```

With `--strict`, any warning becomes a compilation error.

### Warning Suppression

Suppress specific warnings:

```Walrus
// Walrus:ignore unused-variable
var intentionally_unused int = 42;
```

### Warning Levels

Control warning verbosity:

```bash
./bin/Walrus compile program.wl --Wall      # All warnings
./bin/Walrus compile program.wl --Wextra    # Extra pedantic warnings
./bin/Walrus compile program.wl --Wno-unused-variable  # Disable specific warning
```

### Warning Codes

Each warning gets a unique code for documentation and suppression:

```
W001: Unused variable
W002: Unreachable code
W003: Integer division truncation
W004: Shadowed variable
```

## Design Decisions

### Why Non-Fatal?

Warnings catch potential issues without blocking development velocity. A program with warnings is still valid and will execute.

### Why Collect vs Display Immediately?

**Benefits:**
- See all issues at once
- Doesn't clutter pass-by-pass progress
- Easier to scan multiple warnings
- Can implement warning deduplication

### Why Global Context?

**Benefits:**
- Warnings survive across passes
- Simple API: just append to array
- No need to thread through return values
- Easy to clear between compilations

### Why Separate CompilerWarning Class?

**Benefits:**
- Clear separation: errors are fatal, warnings aren't
- Different display logic possible
- Can add warning-specific features (codes, suppression)
- Cleaner type checking

## Testing

Run warning tests:

```bash
ruby tests/unit/test_warnings.rb
```

Test with fixtures:

```bash
./bin/Walrus compile tests/fixtures/warnings/unused_var.wl
```

## References

- `compiler_error.rb` - CompilerWarning class definition
- `compile.rb:385-387` - Warning context initialization
- `compile.rb:290-295` - Warning display after compilation
- `compiler_passes/05_5_infer_and_check_types.rb` - Unused variable detection
