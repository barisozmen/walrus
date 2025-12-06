// Time Converter and Calculator
// Converts between time units and calculates durations
// Demonstrates: functions, case/when, arithmetic, modulo operations, for loops

func seconds_to_minutes(seconds int) int {
    return seconds / 60;
}

func seconds_to_hours(seconds int) int {
    return seconds / 3600;
}

func seconds_to_days(seconds int) int {
    return seconds / 86400;  // 60 * 60 * 24
}

func format_time(total_seconds int) int {
    // Returns days, hours, minutes, seconds as separate prints
    var days = total_seconds / 86400;
    var remaining = total_seconds - (days * 86400);

    var hours = remaining / 3600;
    remaining = remaining - (hours * 3600);

    var minutes = remaining / 60;
    var seconds = remaining - (minutes * 60);

    print days;
    print hours;
    print minutes;
    print seconds;

    return 0;  // Success
}

func calculate_work_hours(hours_per_day int, days int) int {
    return hours_per_day * days;
}

func calculate_overtime(regular_hours int, actual_hours int, overtime_rate int) int {
    if actual_hours > regular_hours {
        var overtime = actual_hours - regular_hours;
        return overtime * overtime_rate / 100;
    } else {
        return 0;
    }
}

// Demo 1: Convert seconds to formatted time
var total_seconds = 93784;  // 1 day, 2 hours, 3 minutes, 4 seconds
format_time(total_seconds);

// Demo 2: Calculate work hours in a month
var hours_per_day = 8;
var work_days = 22;
var monthly_hours = calculate_work_hours(hours_per_day, work_days);
print monthly_hours;

// Demo 3: Calculate weekly schedule
var week_schedule = 0;
var day = 0;
for (day = 1; day <= 7; day = day + 1) {
    case day {
        when 1 { week_schedule = week_schedule + 8; }   // Monday
        when 2 { week_schedule = week_schedule + 8; }   // Tuesday
        when 3 { week_schedule = week_schedule + 8; }   // Wednesday
        when 4 { week_schedule = week_schedule + 8; }   // Thursday
        when 5 { week_schedule = week_schedule + 6; }   // Friday (short day)
        when 6 { week_schedule = week_schedule + 0; }   // Saturday
        when 7 { week_schedule = week_schedule + 0; }   // Sunday
    }
}
print week_schedule;  // Total weekly hours

// Demo 4: Calculate overtime pay multiplier
var regular_weekly = 40;
var actual_weekly = 50;
var overtime_multiplier = 150;  // 150% = 1.5x pay
var overtime_bonus = calculate_overtime(regular_weekly, actual_weekly, overtime_multiplier);
print overtime_bonus;

// Demo 5: Convert various time periods to seconds
var minutes_in_day = 60 * 24;
var seconds_in_week = 60 * 60 * 24 * 7;
var seconds_in_year = 60 * 60 * 24 * 365;

print minutes_in_day;
print seconds_in_week;
print seconds_in_year;
