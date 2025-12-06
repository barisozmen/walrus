// relations.wl
//
// Tests of additional relations

var x = 2;
var y = 5;

// Every test should print "1"
if x < y {
   print 1;
} else {
   print 0;
}

if x <= y {
   print 1;
} else {
   print 0;
}

if y > x {
   print 1;
} else {
   print 0;
}

if y >= x {
   print 1;
} else {
   print 0;
}

if x == y {
   print 0;
} else {
   print 1;
}

if x != y {
   print 1;
} else {
   print 0;
}
