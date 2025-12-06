require_relative 'base'

module Walrus
  class CompileWithRuntime < CompilerPass
    def run(llvm_ir)
      raise ArgumentError, "Expected String" unless llvm_ir.is_a?(String)

      write_llvm(llvm_ir)
      compile_executable
    end

    private

    def write_llvm(llvm_ir)
      File.write('out.ll', llvm_ir)
    end

    def compile_executable
      runtime_path = File.join(__dir__, '..', 'runtime.c')
      system("clang out.ll #{runtime_path} -o out.exe")

      if $?.success?
        puts "✓ Compiled to: out.exe"
        "out.exe"
      else
        raise "Compilation failed"
      end
    end
  end
end
