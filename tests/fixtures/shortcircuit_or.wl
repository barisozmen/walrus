// Test short-circuit 'or' - should NOT evaluate second operand
var x = 0;
if x == 0 or 100/x > 0 {
    print 7;
}
