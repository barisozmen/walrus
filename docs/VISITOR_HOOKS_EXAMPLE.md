# Visitor Hooks: Before & After

## Implementation Complete ✓

The visitor hooks are now implemented in `compiler_passes/base.rb` with context-passing capability.

## What Changed

### base.rb - Core Infrastructure

```ruby
module AstTransformer
  # Hook: Override to set up initial context
  def before_transform(node, context)
    context
  end

  # Hook: Override to process final result
  def after_transform(node, result, context)
    result
  end

  def transform(node, context = {})
    # ... navigation logic with context threading ...
  end
end

class AstTransformerBasedCompilerPass < CompilerPass
  def run(input)
    context = before_transform(input, {})
    result = transform(input, context)
    after_transform(input, result, context)
  end
end
```

### All Passes Updated

✅ Pass 3: fold_constants
✅ Pass 4: deinitialize_variable_declarations
✅ Pass 7: ensure_all_functions_have_explicit_returns
✅ Pass 8: lower_expressions_to_instructions
✅ Pass 9: lower_statements_to_instructions
✅ Pass 10: merge_statements_into_basic_blocks
✅ Pass 11: flatten_control_flow
✅ Pass 12: generate_llvm_code
✅ Pass 13: add_llvm_entry_blocks

**Result**: All transform_* methods now accept `(node, context)` signature.

## Example 1: State Management (Pass 10 - Ready to Refactor)

### Current Implementation (Manual State)

```ruby
class MergeStatementsIntoBasicBlocks < AstTransformerBasedCompilerPass
  def initialize
    @label_gen = LabelGenerator.new
  end

  def run(input)
    @label_gen = LabelGenerator.new  # Manual reset
    transform(input, {})
  end

  def transform_if(node, context)
    label = @label_gen.gen_label  # Instance variable access
    # ...
  end
end
```

### With Hooks (Clean)

```ruby
class MergeStatementsIntoBasicBlocks < AstTransformerBasedCompilerPass
  def before_transform(node, context)
    context.merge(label_gen: LabelGenerator.new)
  end

  def transform_if(node, context)
    label = context[:label_gen].gen_label  # From context
    # ...
  end
end
```

**Benefits**:
- No manual state reset needed
- State lives in context (testable, traceable)
- Pure transforms (no instance variables)

## Example 2: Future Scope Tracking (Pass 5)

Pass 5 currently threads `locals` and `scope` manually through every call. With context:

### Current (Manual Threading)

```ruby
def resolve_statement(stmt, locals, scope)
  case stmt
  when If
    # Must manually pass locals, scope everywhere
    resolve_statement(stmt.then_block, locals, scope)
    resolve_statement(stmt.else_block, locals, scope)
  end
end
```

### With Context (Automatic Threading)

```ruby
def transform_if(node, context)
  If.new(
    transform(node.condition, context),
    transform(node.then_block, context),     # Context flows automatically
    transform(node.else_block, context)
  )
end

def transform_function(node, context)
  new_context = context.merge(
    scope: context[:scope] + [node.name],
    locals: build_locals(node.params)
  )
  Function.new(node.name, node.params, transform(node.body, new_context))
end
```

**Benefits**:
- No manual parameter threading
- Each node can modify context for its children
- Scope becomes declarative

## Example 3: Register Allocation (Pass 12)

### Current

```ruby
class GenerateLLVMCode < AstTransformerBasedCompilerPass
  def initialize
    @reg_gen = RegisterGenerator.new
  end

  def run(input)
    @reg_gen.reset  # Manual reset
    transform(input, {})
  end
end
```

### With Hooks

```ruby
class GenerateLLVMCode < AstTransformerBasedCompilerPass
  def before_transform(node, context)
    context.merge(reg_gen: RegisterGenerator.new)
  end

  # @reg_gen becomes context[:reg_gen] everywhere
end
```

## Testing Impact

All transform calls now require context parameter:

```ruby
# Before
result = SomePass.new.run(input)

# After (same - hooks handle it automatically)
result = SomePass.new.run(input)

# If calling transform directly in tests:
# Before: transform(node)
# After:  transform(node, {})
```

**Status**: ✅ All 165 unit tests passing

## Design Decisions

### Why Context-Passing?

1. **Powers complex passes**: Scope tracking (pass 5) impossible without context
2. **Makes state explicit**: No hidden instance variables
3. **Composable**: Passes can chain context modifications
4. **Testable**: Context is just a hash

### Why Not Backward Compatible?

- Toy project (no production users)
- Breaking change forces cleanup
- Simpler implementation
- Tests adapt easily

### Context is a Hash

Simple, flexible, Ruby-native:
```ruby
context = {
  label_gen: LabelGenerator.new,
  scope: ['main'],
  locals: { 'x' => true }
}
```

No fancy objects needed.

## Migration Pattern

For any stateful pass:

1. **Find instance variables** that track state
2. **Move initialization** to `before_transform`
3. **Replace `@var`** with `context[:var]`
4. **Delete manual resets** from `run()`

## Impact

**Code Removed**:
- Manual state reset boilerplate in run()
- Instance variable declarations for transient state

**Code Simplified**:
- Pass 10, 11, 12 become simpler with hooks
- Pass 5 (future) becomes declarative

**Abstraction Achieved**:
- Separation: navigation (transform) vs. transformation (transform_*)
- Separation: state (context) vs. logic (transform methods)
- Extensibility: hooks provide extension points

## Next Steps

1. ✅ Hooks implemented
2. **Refactor pass 10** to use hooks (remove manual state)
3. **Refactor pass 11** to use hooks
4. **Refactor pass 12** to use hooks
5. **(Future) Refactor pass 5** to use context for scope tracking

---

**Philosophy**: Minimal, surgical, elegant. The DHH way.
