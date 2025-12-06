// shortcircuit.wl
//
// This test is related to the addition of 'and' and 'or' operators
// and short-circuit evaluation behvaior.   This program should
// print "1" twice and have no zero-division errors.

var x = 0;

if x != 0 and 100/x > 0 {
    print x;
} else {
    print 1;
}

if x == 0 or 100/x > 0 {
   print 1;
} else {
   print 0;
}

