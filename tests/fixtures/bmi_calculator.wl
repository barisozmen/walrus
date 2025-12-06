// BMI (Body Mass Index) Calculator
// Calculates BMI and provides health category
// Demonstrates: floats, functions, if/elsif/else chains, gets

func calculate_bmi(weight_kg float, height_m float) float {
    return weight_kg / (height_m * height_m);
}

func get_bmi_category(bmi float) int {
    // Returns category code:
    // 1 = Underweight (< 18.5)
    // 2 = Normal (18.5 - 24.9)
    // 3 = Overweight (25.0 - 29.9)
    // 4 = Obese (>= 30.0)

    if bmi < 18.5 {
        return 1;
    } elsif bmi < 25.0 {
        return 2;
    } elsif bmi < 30.0 {
        return 3;
    } else {
        return 4;
    }
}

// Get user input
var weight = gets;  // Weight in kg
var height = gets;  // Height in meters

// Calculate BMI
var bmi = calculate_bmi(weight, height);
print bmi;

// Get category
var category = get_bmi_category(bmi);
print category;

// Calculate healthy weight range for given height
var min_healthy = 18.5 * (height * height);
var max_healthy = 24.9 * (height * height);
print min_healthy;
print max_healthy;
