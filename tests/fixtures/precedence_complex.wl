// precedence_complex.wl
//
// Tests complex expressions with mixed precedence and parentheses

var x = 10;
var y = 5;
var z = 2;

// Complex without parens: 10 + 5 * 2 - 8 / 2 = 10 + 10 - 4 = 16
print x + y * z - 8 / 2;

// Parentheses override precedence: (10 + 5) * 2 = 30
print (x + y) * z;

// Nested expressions: 10 * (5 + 2) - 8 = 10 * 7 - 8 = 62
print x * (y + z) - 8;

// All four operators: 100 / 10 + 5 * 3 - 2 = 10 + 15 - 2 = 23
print 100 / x + y * 3 - z;

// Deep nesting: ((10 + 5) * 2 - 8) / 2 = (15 * 2 - 8) / 2 = 22 / 2 = 11
print ((x + y) * z - 8) / z;

// Unary in expression: -10 + 5 * 2 = -10 + 10 = 0
print -x + y * z;
