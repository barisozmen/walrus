// Function to check if a number is prime
func isPrime(n int) int {
    // Numbers less than 2 are not prime
    if n < 2 {
        return 0;
    }
    
    // 2 is prime
    if n == 2 {
        return 1;
    }
    
    // Check if n is divisible by 2
    var remainder int = n - ((n / 2) * 2);
    if remainder == 0 {
        return 0;
    }
    
    // Check divisibility by odd numbers from 3
    var i int = 3;
    
    // We'll check up to sqrt(n), but since we don't have sqrt,
    // we'll use the equivalent check i*i <= n
    while (i * i) <= n {
        remainder = n - ((n / i) * i);
        if remainder == 0 {
            return 0;
        }
        i = (i + 2);
    }
    
    return 1;
}

// Function to print the first N prime numbers
func printFirstNPrimes(n int) int {
    var count int = 0;
    var num int = 2;
    
    while count < n {
        if isPrime(num) == 1 {
            print num;
            count = (count + 1);
        }
        num = (num + 1);
    }
    
    return count;
}

printFirstNPrimes(100);