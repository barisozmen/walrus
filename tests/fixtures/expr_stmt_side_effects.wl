// Expression statements with side effects

var counter int;
counter = 0;

func increment() int {
    counter = counter + 1;
    return counter;
}

// Calls that modify state but we ignore return values
increment();
increment();
increment();

print counter;
