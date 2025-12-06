// Test short-circuit 'and' - should NOT crash on division by zero
var x = 0;
if x != 0 and 100/x > 0 {
    print 999;
}
print 42;
