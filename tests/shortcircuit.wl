// Short-circuit evaluation test
// This program tests that 'and' and 'or' operators properly short-circuit

var x = 0;

// Test 1: 'and' with division by zero
// Should NOT crash because x != 0 is false, so 100/x never evaluates
if x != 0 and 100/x > 0 {
    print x;
}

// Test 2: 'or' with division by zero
// Should print 0 because x == 0 is true, so 100/x never evaluates
if x == 0 or 100/x > 0 {
    print x;
}

// Test 3: 'and' when both sides evaluate
var y = 5;
if y > 0 and y < 10 {
    print y;
}

// Test 4: 'or' when second side evaluates
var z = 15;
if z < 10 or z > 12 {
    print z;
}
