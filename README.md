# Walrus
Toy programming language with rich error messages and easy to understand compiler architecture.

<img width="512" height="280" alt="image" src="https://github.com/user-attachments/assets/8f07611b-eed7-4f69-be10-5ca94cb9017e" />

### Why give it a try?
Primary design goal of Walrus is being easy to understand and debug. So that you can get into speed quickly and extend it with your favorite language features.

Walrus has:
- Rich error messages with hints
- A clear Ruby implementation
- Static typing

### Getting Started
```bash
git clone https://github.com/barisozmen/walrus.git && cd walrus
bundle install
bin/walrus compile --run draw_julia_set.wl
```

### Syntax
You can understand great deal of the language syntax just by reading [compiler_passes/01_tokenizer.rb](compiler_passes/01_tokenizer.rb) and [compiler_passes/02_parser.rb](compiler_passes/02_parser.rb). Both files are descriptive and fairly short. They are the source of truth.

For a quicker overview:
- Types: `int`, `float`, `char`, `str`
- Control expressions: `if`, `elsif`, `else`, `while`, `for`, `case`
- Operators: `+`, `-`, `*`, `/`, `==`, `!=`, `<`, `>`, `<=`, `>=`, `and`, `or`
- Functions: `func`, `return`, `break`, `continue`
- Local and global variables: `var`
- Comments: `//`

Example program:
```c
// 3-band heat fractal

var band1 = 0.5;
var band2 = 2.0;

func heat(x float, y float) char {
    var v = (x*x) + (y*y);
    if v < band1 { return 'o'; }
    if v < band2 { return '*'; }
    return '#';
}

for (var y = -1.0; y <= 1.0; y = y + 0.1) {
    for (var x = -3.0; x <= 3.0; x = x + 0.15) {
        print heat(x, y);
    }
    print '\n';
}
```

See [tests/fixtures/](tests/fixtures/) for more examples

### Performance characteristics
- Slow compilation (written in Ruby)
- Fast execution (targets [LLVM](https://llvm.org/), direct to machine)

### Compilation Steps
You can get a clear picture from [compiler_passes/](compiler_passes/). Each step is numbered and their code should be easy to read. Also find unit tests for each compilation step in [tests/unit/](tests/unit/), they clearly show what goes in and what goes out at each stage.

### Contributing & What is missing
If you'd like to contribute, please make a PR with merge request, or just reach me out at [x.com/barisozmen_twi](https://x.com/barisozmen_twi) to talk about your ideas.

Followings are what we need:
- Garbage collection
- File I/O
- Standard library
- Classes with polymorphism and behavior mixins
- Built-in debugger
- string addition during runtime (LLVM level)
- type castings during runtime (LLVM level)
- testing & bug fixing