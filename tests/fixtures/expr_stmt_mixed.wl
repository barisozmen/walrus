// Mix of expression statements and assignments

func add(a int, b int) int {
    return a + b;
}

var result int;

// Assignment - store return value
result = add(10, 20);
print result;

// Expression statement - discard return value
add(100, 200);

// result unchanged
print result;
