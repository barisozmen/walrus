// Test nested case inside elsif
var x = 2;
var y = 20;

if x == 1 {
  print 100;
} elsif x == 2 {
  case y {
    when 10 { print 210; }
    when 20 { print 220; }
    else { print 200; }
  }
} else {
  print 999;
}
