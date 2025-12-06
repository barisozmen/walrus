// Computing Pi using a simplified Machin-like formula
// π = 16*arctan(1/5) - 4*arctan(1/239)
// We'll use integer arithmetic with a fixed scaling factor

// Simple arctan calculation using power series with integer arithmetic
// arctan(x) = x - x^3/3 + x^5/5 - x^7/7 + ...
// We'll scale everything by 10^6 to work with integers

// Calculate arctan(1/divisor) * scale
func arctanScaled(divisor int, scale int) int {
    var result int = 0;
    var power int = divisor;              // First power is divisor
    var term int = (scale / divisor);     // First term is scale/divisor
    var sign int = 1;                     // First term is positive
    var i int = 1;                        // Current term
    var iteration int = 0;                // Count iterations to prevent infinite loop
    
    // We'll add terms until they're too small to matter
    while term > 0 {
        // Add or subtract the term based on sign
        if sign == 1 {
            result = (result + term);
        } else {
            result = (result - term);
        }
        
        // For next term: multiply by divisor^2 and divide by next odd number
        power = (power * divisor);    // divisor^i
        power = (power * divisor);    // divisor^(i+1)
        i = (i + 2);                  // Next odd number
        term = (scale / (power * i)); // scale/(divisor^(i+1) * i)
        sign = (1 - sign);            // Flip sign for next term
        
        // Safety check to prevent infinite loops - limit to 10 iterations
        iteration = (iteration + 1);
        if iteration >= 10 {
            return result;
        }
    }
    
    return result;
}

// Calculate PI using Machin's formula: π = 16*arctan(1/5) - 4*arctan(1/239)
// Results scaled by our fixed scale factor
func calculatePiScaled(scale int) int {
    var term1 int = arctanScaled(5, scale);
    var term2 int = arctanScaled(239, scale);
    
    term1 = (term1 * 16);     // 16*arctan(1/5)
    term2 = (term2 * 4);      // 4*arctan(1/239)
    
    return (term1 - term2);   // π * scale
}

// Print digits of pi one at a time
func printPiDigits(digits int) int {
    // We'll use 10^9 as our scaling factor - large enough for good precision
    var scale int = 1000000000;  // 10^9

    // Calculate pi * scale
    var piScaled int = calculatePiScaled(scale);
    
    // Pi is approximately 3.14159...
    // First, print the integer part
    print 3;
    

    // Extract remaining digits
    var divisor int = (scale / 10);  // scale/10
    var i int = 0;
    
    // Subtract the integer part (3)
    piScaled = (piScaled - (3 * scale));
    
    // Extract each digit
    while i < digits {
        // Get next digit
        var digit int = (piScaled / divisor);
        
        // Print the digit
				print digit;
        
        // Remove the digit we just printed
        piScaled = (piScaled - (digit * divisor));
        
        // Shift for next digit
        piScaled = (piScaled * 10);

        i = (i + 1);
    }
    return 0;
}

    
// Calculate first 10 digits of pi
printPiDigits(10);