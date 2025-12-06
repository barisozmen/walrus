// fib.wl
//
// Recursive Fibonacci numbers.  A particularly bad way to Fibonacci.

func fib(n int) int {
    if n < 2 {
        return 1;
    } else {
        return fib(n-1) + fib(n-2);
    }
}

var LAST = 30;
var n = 0;
while n < LAST {
    print fib(n);
    n = n + 1;
}
