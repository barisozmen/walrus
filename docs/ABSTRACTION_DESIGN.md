# Walrus Compiler Abstraction Layer

## The Problem

Compiler passes share repetitive patterns but lack clean abstraction points. Three major categories of repetition:

1. **Manual AST traversal** with case statements (passes 5, 11)
2. **Stateful transformations** that reset state and track context (passes 10, 11, 12)
3. **Operator dispatch** - same case statement 3+ times (passes 3, 8, 12)

## The Solution

Two surgical enhancements to the existing `AstTransformer` foundation:

### 1. Context Walker

**What it solves**: Manual scope/context threading through recursive traversal

**Pattern Identified**:
```ruby
# Pass 5: Scope resolver - manually threads locals and scope everywhere
def resolve_statement(stmt, locals, scope)
  case stmt
  when If
    resolve_statement(stmt.then_block, locals, scope)  # Manual threading
    resolve_statement(stmt.else_block, locals, scope)  # Manual threading
  # ... 10+ more cases
end
```

**With Context Walker**:
```ruby
class ResolveVariableScopes < AstTransformerBasedCompilerPass
  def transform_if(node, context)
    If.new(
      transform(node.condition, context),
      transform(node.then_block, context),
      transform(node.else_block, context)
    )
  end

  def transform_function(node, context)
    new_context = context.merge(scope: context[:scope] + [node.name], locals: {})
    Function.new(node.name, node.params, transform(node.body, new_context))
  end
end
```

**API**:
- `transform(node, context = {})` - context flows through recursion
- Override `transform_<nodetype>(node, context)` to access/modify context
- Context is a hash - put whatever you need (locals, scope, labels, registers)

**Benefits**:
- Scope tracking becomes declarative
- No manual parameter threading
- Each node transformation can add/modify context
- Still uses existing transform infrastructure

### 2. Visitor Hooks (IMPLEMENTED)

**What it solves**: Stateful passes that need initialization and cleanup

**Pattern Identified**:
```ruby
# Pass 10, 11, 12 all do this:
class SomePass < AstTransformerBasedCompilerPass
  def initialize
    @label_gen = LabelGenerator.new
  end

  def run(input)
    @label_gen = LabelGenerator.new  # Reset state
    transform(input)
  end
end
```

**With Visitor Hooks**:
```ruby
class SomePass < AstTransformerBasedCompilerPass
  def before_transform(node, context)
    context.merge(label_gen: LabelGenerator.new)
  end

  def transform_if(node, context)
    label = context[:label_gen].new_label  # Use from context
    # ... transformation
  end
end
```

**API**:
- `before_transform(node, context)` - Called once before traversal, returns initial context
- `after_transform(node, result, context)` - Called once after traversal, returns final result
- Both are hooks—override to customize behavior

**Benefits**:
- State initialization in one place
- No manual state reset
- State travels in context (testable, pure)
- Cleanup/post-processing in after_transform

### Implementation

**File**: `Walrus/compiler_passes/base.rb`

**Changes**:
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

  # Core transform - now context-aware
  def transform(node, context = {})
    return node.flat_map { |item| transform(item, context) } if node.is_a?(Array)

    method_name = "transform_#{node.class.name.downcase}"
    if respond_to?(method_name, true)
      send(method_name, node, context)
    else
      # Default: recursively transform children with context
      node.class.new(*node.attr_names.map { |name|
        transform(node.instance_variable_get("@#{name}"), context)
      })
    end
  end
end

class AstTransformerBasedCompilerPass < CompilerPass
  include AstTransformer

  def run(input)
    context = before_transform(input, {})
    result = transform(input, context)
    after_transform(input, result, context)
  end
end
```

**Migration Path**:
1. Add context parameter to all transform methods: `transform(node, context = {})`
2. Update transform_<nodetype> methods to accept context: `def transform_binop(node, context)`
3. Tests break only where transform is called—add empty hash: `transform(node, {})`

### Examples

**Example 1: State Reset (Pass 10)**
```ruby
# Before: Manual state management
class MergeStatementsIntoBasicBlocks < AstTransformerBasedCompilerPass
  def run(input)
    @label_gen = LabelGenerator.new
    transform(input)
  end

  def transform_if(node)
    label = @label_gen.new_label  # Instance variable
    # ...
  end
end

# After: Hooks
class MergeStatementsIntoBasicBlocks < AstTransformerBasedCompilerPass
  def before_transform(node, context)
    context.merge(label_gen: LabelGenerator.new)
  end

  def transform_if(node, context)
    label = context[:label_gen].new_label  # From context
    # ...
  end
end
```

**Example 2: Scope Tracking (Future: Pass 5)**
```ruby
class ResolveVariableScopes < AstTransformerBasedCompilerPass
  def before_transform(node, context)
    context.merge(scope: [], locals: {})
  end

  def transform_function(node, context)
    new_locals = node.params.each_with_object({}) { |p, h| h[p] = true }
    new_context = context.merge(
      scope: context[:scope] + [node.name],
      locals: new_locals
    )
    Function.new(node.name, node.params, transform(node.body, new_context))
  end

  def transform_name(node, context)
    if context[:locals][node.value]
      LocalName.new(node.value)
    else
      GlobalName.new(node.value, context[:scope])
    end
  end
end
```

## Design Principles

Following POODR and Unix Philosophy:

1. **Separation of Concerns**: Navigation (transform) vs. transformation (transform_X)
2. **Do One Thing Well**: Each pass focuses on its transformation logic
3. **Composable**: Context flows through, passes can chain behaviors
4. **Tell, Don't Ask**: Hooks tell the framework what to do, don't ask for state
5. **Open/Closed**: Base is closed for modification, open via hooks

## Tradeoffs

**Context-Passing Hooks**:
- ✅ Powers both simple and complex passes
- ✅ Makes state explicit (testable, traceable)
- ✅ Enables scope tracking without manual threading
- ❌ Breaking change (all transform methods need context param)
- ❌ Slightly more verbose calls

**Chosen**: Context-passing because it unlocks the hardest problem (scope resolution) while solving the easy one (state reset).

## What We're NOT Building

- Not a full visitor framework (too heavy)
- Not automatically tracking all state (too magic)
- Not handling control flow flattening (too specific)
- Not abstracting operator dispatch yet (separate concern)

## Next Steps

1. ✅ Implement hooks in base.rb
2. Refactor pass 10 to use hooks (proof of concept)
3. Refactor pass 11 (flatten control flow)
4. Refactor pass 12 (LLVM generation)
5. (Future) Refactor pass 5 using context for scope

## Success Metrics

- Remove ~50 lines of state management boilerplate
- Make state flow explicit and testable
- Enable future scope resolver refactor
- All tests still pass
