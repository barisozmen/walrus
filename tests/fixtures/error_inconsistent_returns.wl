// This should error: inconsistent return types

func bad(x int) {
    if x < 0 {
        return 0;      // int
    } else {
        return 0.0;    // float - ERROR!
    }
}

print bad(5);
