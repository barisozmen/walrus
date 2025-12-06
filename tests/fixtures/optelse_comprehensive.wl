// Test both optional else and traditional if-else

// 1. Optional else (new feature)
func abs(x int) int {
   if x < 0 {
      return 0 - x;
   }
   return x;
}

// 2. Traditional if-else (still works)
func max(a int, b int) int {
   if a > b {
      return a;
   } else {
      return b;
   }
}

// 3. Multiple optional else in sequence
func classify(n int) int {
   if n < 0 {
      return 0 - 1;
   }
   if n == 0 {
      return 0;
   }
   return 1;
}

print abs(5);
print abs(0-3);
print max(10, 20);
print max(30, 15);
print classify(0-5);
print classify(0);
print classify(42);
