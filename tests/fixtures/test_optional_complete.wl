// Complete test: Optional initial values

var a = 10;      // With initial value
var b int;           // Without initial value
var c = a + b;   // Mix of both

print a;         // 10
print b;         // 0 (default)
print c;         // 10

b = 5;
c = a + b;
print c;         // 15
