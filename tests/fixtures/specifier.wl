// This file adds type-specifiers to declarations that require them.
// This affect variables declarations and functions.

var x = 4;
var y int;               // Type is required on variables with no value

func square(a int) int {  // Types are required on functions
     var result = a*a;
     return result;
}

y = square(x);
print y;


