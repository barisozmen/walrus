// Nested for-loops test
for (var i = 0; i < 3; i = i + 1) {
    for (var j = 0; j < 3; j = j + 1) {
        var x = i * 10;
        var result = x + j;
        print result;
    }
}
