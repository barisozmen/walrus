// Temperature Converter
// Converts between Celsius and Fahrenheit
// Demonstrates: case/when, functions, floats, gets, string operations

func celsius_to_fahrenheit(c float) float {
    return c * 9.0 / 5.0 + 32.0;
}

func fahrenheit_to_celsius(f float) float {
    return (f - 32.0) * 5.0 / 9.0;
}

func kelvin_to_celsius(k float) float {
    return k - 273.15;
}

func celsius_to_kelvin(c float) float {
    return c + 273.15;
}

// Print menu and process conversions
print 1;  // 1 = Celsius to Fahrenheit
print 2;  // 2 = Fahrenheit to Celsius
print 3;  // 3 = Celsius to Kelvin
print 4;  // 4 = Kelvin to Celsius

var choice = gets;
var temp = gets;

case choice {
    when 1 {
        var result = celsius_to_fahrenheit(temp);
        print result;
    }
    when 2 {
        var result = fahrenheit_to_celsius(temp);
        print result;
    }
    when 3 {
        var result = celsius_to_kelvin(temp);
        print result;
    }
    when 4 {
        var result = kelvin_to_celsius(temp);
        print result;
    }
    else {
        print 0;  // Invalid choice
    }
}
