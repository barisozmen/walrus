// continue_skip_evens.wl
//
// Test continue statement that skips even numbers
// Only prints odd numbers from 0 to 9

var n = 0;
while n < 10 {
    n = n + 1;

    // Skip even numbers (when n/2*2 == n)
    var half = n / 2;
    var doubled = half * 2;
    if doubled == n {
        continue;
    }

    print n;
}
