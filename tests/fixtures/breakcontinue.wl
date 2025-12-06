// breakcontinue.wl
//
// This test is for break and continue statements which alter control
// flow in loops.

var n = 0;
while n >= 0 {
    print n;
    if n >= 10 {
        break;      // Exits the loop
    }
    if n < 10 {
        n = n + 1;
        continue;   // Skips back to top
    }
    n = 0;
}

var x = 0;
while x >= 0 {
    if x == 10 {
        break;
    } else {
        var y = 0;
        while y >= 0 {
            if y == 10 {
                break;
            } else {
                print x * y;
                y = y + 1;
            } 
        }
        x = x + 1;
    }
}
