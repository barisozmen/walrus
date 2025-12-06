// julia.wl - Draw a Julia set

var xmin = -1.5; var xmax = 1.5;
var ymin = -1.0; var ymax = 1.0;
var width = 40.0; var height = 20.0;
var thresh = 200;
var cx = -0.7; var cy = 0.27015;

func in_julia(x float, y float, n int) int {
    var xt float;
    while n > 0 {
        xt = ((x*x) - (y*y)) + cx;
        y = ((2.0*x)*y) + cy;
        x = xt;
        n = n - 1;
        if ((x*x) + (y*y)) > 4.0 {
            return 0;
        }
    }
    return 1;
}

var dx = (xmax - xmin)/width;
var dy = (ymax - ymin)/height;
var yy = ymax; var xx float;

while yy >= ymin {
    xx = xmin;
    while xx < xmax {
        if in_julia(xx, yy, thresh) == 1 {
            print '*';
        } else {
            print '.';
        }
        xx = xx + dx;
    }
    print '\n';
    yy = yy - dy;
}
