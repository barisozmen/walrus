// breakcontinue_in_highly_nested_loops.wl
//
// Test break and continue with 5 levels of nested loops
// Verifies that break/continue only affect the innermost loop

var a = 0;
while a < 2 {
    var b = 0;
    while b < 2 {
        var c = 0;
        while c < 2 {
            var d = 0;
            while d < 2 {
                var e = 0;
                while e < 3 {
                    // Print current position (a*10000 + b*1000 + c*100 + d*10 + e)
                    var temp_a = a * 10000;
                    var temp_b = b * 1000;
                    var temp_c = c * 100;
                    var temp_d = d * 10;
                    var pos = temp_a;
                    pos = pos + temp_b;
                    pos = pos + temp_c;
                    pos = pos + temp_d;
                    pos = pos + e;
                    print pos;

                    // Continue skips e=1
                    if e == 1 {
                        e = e + 1;
                        continue;
                    }

                    // Break exits when e=2
                    if e == 2 {
                        break;
                    }

                    e = e + 1;
                }
                d = d + 1;
            }
            c = c + 1;
        }
        b = b + 1;
    }
    a = a + 1;
}
