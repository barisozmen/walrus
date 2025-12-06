// precedence_chain.wl
//
// Tests chaining multiple operators of same precedence

var a = 100;
var b = 20;
var c = 10;
var d = 5;

// Chain addition: 1 + 2 + 3 + 4 = 10
print 1 + 2 + 3 + 4;

// Chain multiplication: 2 * 3 * 4 = 24
print 2 * 3 * 4;

// Chain subtraction (left-associative): 100 - 20 - 10 - 5 = 65
print a - b - c - d;

// Chain division (left-associative): 100 / 2 / 5 = 10
print 100 / 2 / 5;

// Mixed same-level: 100 + 10 - 20 + 5 = 95
print 100 + 10 - 20 + 5;

// Mixed same-level: 100 * 2 / 4 = 50
print 100 * 2 / 4;
