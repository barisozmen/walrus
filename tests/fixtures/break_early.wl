// break_early.wl
//
// Test break statement that exits loop immediately on first iteration

var found = 0;
var i = 0;

while i < 100 {
    print i;
    if i == 0 {
        found = 1;
        break;
    }
    i = i + 1;
}

print found;
