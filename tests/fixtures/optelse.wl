// Test of optional else clause

func abs(x int) int {
   if x < 0 {
      return 0 - x;
   }
   return x;
}

print abs(2);
print abs(-2);
