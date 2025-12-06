// Test of floating point operations

var x = 2.1;
var y = 3.4;
var z = x + y;

print z;
print x - y;
print x * y;
print x / y;
print -x;

func f(a float, b float) float {
    var c = a + b;
    return c;
}
print f(x, y);

// All of these should print "1"
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

if x <= x {
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

if y >= y {
   print 1;
} else {
   print 0;
}

if x == x {
   print 1;
} else {
   print 0;
}

if x != y {
   print 1;
} else {
   print 0;
}




