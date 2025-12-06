// Test of variable declaration with no initial value
var x int;        // No initial value

func setx(v int) int {
    x = v;
    return x;
}

print x;         // -> ?
print setx(123); // -> 123
print x;         // -> 123
