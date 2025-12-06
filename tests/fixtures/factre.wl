// Compute factorials
      
func fact(n int) int {
   if n == 0 {
      return 1;
   } else {
      return n * fact(n-1);
   }
}

var x = 1;
while x < 10 {
    print fact(x);
    x = x + 1;
}
