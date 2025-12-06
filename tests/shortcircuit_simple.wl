// Minimal short-circuit test from the challenge
var x = 0;

// Should NOT crash (short-circuit prevents 100/x evaluation)
if x != 0 and 100/x > 0 {
    print x;
}

// Should print 0 (first condition true, never evaluates 100/x)
if x == 0 or 100/x > 0 {
    print x;
}
