# Walrus
Toy programming language with rich error messages and easy to understand compiler architecture.

<img width="512" height="280" alt="image" src="https://github.com/user-attachments/assets/8f07611b-eed7-4f69-be10-5ca94cb9017e" />

### Features
- Rich error messages with hints
- Easy to see under the hood
   - Clear Ruby implementation
- Static typing

### Performance characteristics
Slow compilation (written in Ruby)
Fast execution (targets [LLVM](https://llvm.org/), direct to machine)

### Compilation Steps
see compiler_passes/

### Getting Started
```bash
git clone https://github.com/barisozmen/walrus.git && cd walrus
bundle install
bin/walrus compile --run hello_world.wl
```