// Test optional return types - inferred from return statements

// Simple case - return literal
func square(x int) {
    return x * x;
}

// Return variable
func double(x int) {
    var result = x + x;
    return result;
}

// Multiple returns with same type in if/else branches
func abs(x int) {
    if x < 0 {
        return -x;
    } else {
        return x;
    }
}

// Nested expressions
func addmultiply(a int, b int, c int) {
    return (a + b) * c;
}

// Test with float
func fsquare(x float) {
    return x * x;
}

// Main program
print square(5);         // Should print 25
print double(10);        // Should print 20
print abs(-7);           // Should print 7
print abs(3);            // Should print 3
print addmultiply(2, 3, 4);  // Should print 20
print fsquare(2.5);      // Should print 6.25
