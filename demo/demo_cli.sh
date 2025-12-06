#!/bin/bash
# Demo script for Walrus CLI

cd "$(dirname "$0")/.."

echo "=== Walrus Compiler CLI Demo ==="
echo

echo "1. Show help:"
./bin/wab help
echo
echo "Press Enter to continue..."; read

echo "2. List all compiler passes:"
./bin/wab passes
echo
echo "Press Enter to continue..."; read

echo "3. Compile with default settings:"
./bin/wab compile test.wab
echo
echo "Press Enter to continue..."; read

echo "4. Run the compiled program:"
./out.exe
echo
echo "Press Enter to continue..."; read

echo "5. Compile with custom output name:"
./bin/wab compile test.wab -o calculator
echo
./calculator
echo
echo "Press Enter to continue..."; read

echo "6. Compile with verbose mode (-v):"
./bin/wab compile test.wab -v
echo
echo "Press Enter to continue..."; read

echo "7. Compile and keep IR file:"
./bin/wab compile test.wab -o final -k
echo
echo "Generated files:"
ls -lh final*
echo
echo "LLVM IR content:"
head -20 final.ll
echo

echo "=== Demo Complete ==="
