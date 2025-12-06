// Loan Payment Calculator
// Calculates monthly payment and total interest for a loan
// Demonstrates: for loops, floats, compound calculations, functions

func power(base float, exp int) float {
    var result = 1.0;
    var i = 0;
    for (i = 0; i < exp; i = i + 1) {
        result = result * base;
    }
    return result;
}

func calculate_monthly_payment(principal float, annual_rate float, years int) float {
    // Convert annual rate to monthly rate (as decimal)
    var monthly_rate = annual_rate / 100.0 / 12.0;
    var num_payments = years * 12;

    // Monthly payment formula: P * [r(1+r)^n] / [(1+r)^n - 1]
    var one_plus_r = 1.0 + monthly_rate;
    var factor = power(one_plus_r, num_payments);

    var monthly_payment = principal * (monthly_rate * factor) / (factor - 1.0);
    return monthly_payment;
}

// Get loan details
var principal = gets;      // Loan amount
var annual_rate = gets;    // Annual interest rate (percentage)
var years = gets;          // Loan term in years

// Calculate monthly payment
var monthly = calculate_monthly_payment(principal, annual_rate, years);
print monthly;

// Calculate total amount paid
var total_payments = years * 12;
var total_paid = monthly * total_payments;
print total_paid;

// Calculate total interest
var total_interest = total_paid - principal;
print total_interest;

// Show amortization for first 12 months
var balance = principal;
var month = 0;
var monthly_rate = annual_rate / 100.0 / 12.0;

for (month = 1; month <= 12; month = month + 1) {
    var interest_payment = balance * monthly_rate;
    var principal_payment = monthly - interest_payment;
    balance = balance - principal_payment;

    print month;
    print interest_payment;
    print principal_payment;
    print balance;
}
