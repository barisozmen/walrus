// Number Guessing Game
// User tries to guess a secret number with hints
// Demonstrates: while loops, break, if/elsif, gets, game logic

func abs(x int) int {
    if x < 0 {
        return 0 - x;
    } else {
        return x;
    }
}

func get_hint(guess int, secret int) int {
    // Returns hint code:
    // 0 = Correct
    // 1 = Too low (far)
    // 2 = Too high (far)
    // 3 = Too low (close)
    // 4 = Too high (close)

    var diff = guess - secret;
    var abs_diff = abs(diff);

    if diff == 0 {
        return 0;  // Correct
    } elsif abs_diff <= 5 {
        // Close guess
        if diff < 0 {
            return 3;  // Too low, close
        } else {
            return 4;  // Too high, close
        }
    } else {
        // Far guess
        if diff < 0 {
            return 1;  // Too low, far
        } else {
            return 2;  // Too high, far
        }
    }
}

// Secret number (would be random in real implementation)
var secret = 42;
var max_attempts = 10;
var attempts = 0;
var won = 0;

print max_attempts;  // Show max attempts

while attempts < max_attempts {
    attempts = attempts + 1;
    var guess = gets;

    var hint = get_hint(guess, secret);

    if hint == 0 {
        // Correct guess
        print 100;  // Success code
        print attempts;
        won = 1;
        break;
    } else {
        print hint;
        print attempts;  // Show remaining attempts
    }
}

// Game over
if won == 0 {
    print 999;  // Failed code
    print secret;  // Reveal secret
}
