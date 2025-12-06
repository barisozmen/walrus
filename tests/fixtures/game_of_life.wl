// game_of_life.wl - Conway's Game of Life in Walrus 
// A simple implementation using a fixed-size grid
//

// Grid size - small due to language limitations
var width = 10;
var height = 10;

// Since we don't have arrays, we'll use variables to store the grid
// First generation cells
var c00 = 0; var c01 = 0; var c02 = 0; var c03 = 0; var c04 = 0;
var c05 = 0; var c06 = 0; var c07 = 0; var c08 = 0; var c09 = 0;

var c10 = 0; var c11 = 0; var c12 = 0; var c13 = 0; var c14 = 0;
var c15 = 0; var c16 = 0; var c17 = 0; var c18 = 0; var c19 = 0;

var c20 = 0; var c21 = 0; var c22 = 0; var c23 = 0; var c24 = 0;
var c25 = 0; var c26 = 0; var c27 = 0; var c28 = 0; var c29 = 0;

var c30 = 0; var c31 = 0; var c32 = 0; var c33 = 0; var c34 = 0;
var c35 = 0; var c36 = 0; var c37 = 0; var c38 = 0; var c39 = 0;

var c40 = 0; var c41 = 0; var c42 = 0; var c43 = 0; var c44 = 0;
var c45 = 0; var c46 = 0; var c47 = 0; var c48 = 0; var c49 = 0;

var c50 = 0; var c51 = 0; var c52 = 0; var c53 = 0; var c54 = 0;
var c55 = 0; var c56 = 0; var c57 = 0; var c58 = 0; var c59 = 0;

var c60 = 0; var c61 = 0; var c62 = 0; var c63 = 0; var c64 = 0;
var c65 = 0; var c66 = 0; var c67 = 0; var c68 = 0; var c69 = 0;

var c70 = 0; var c71 = 0; var c72 = 0; var c73 = 0; var c74 = 0;
var c75 = 0; var c76 = 0; var c77 = 0; var c78 = 0; var c79 = 0;

var c80 = 0; var c81 = 0; var c82 = 0; var c83 = 0; var c84 = 0;
var c85 = 0; var c86 = 0; var c87 = 0; var c88 = 0; var c89 = 0;

var c90 = 0; var c91 = 0; var c92 = 0; var c93 = 0; var c94 = 0;
var c95 = 0; var c96 = 0; var c97 = 0; var c98 = 0; var c99 = 0;

// Second generation cells (for calculating the next state)
var n00 = 0; var n01 = 0; var n02 = 0; var n03 = 0; var n04 = 0;
var n05 = 0; var n06 = 0; var n07 = 0; var n08 = 0; var n09 = 0;

var n10 = 0; var n11 = 0; var n12 = 0; var n13 = 0; var n14 = 0;
var n15 = 0; var n16 = 0; var n17 = 0; var n18 = 0; var n19 = 0;

var n20 = 0; var n21 = 0; var n22 = 0; var n23 = 0; var n24 = 0;
var n25 = 0; var n26 = 0; var n27 = 0; var n28 = 0; var n29 = 0;

var n30 = 0; var n31 = 0; var n32 = 0; var n33 = 0; var n34 = 0;
var n35 = 0; var n36 = 0; var n37 = 0; var n38 = 0; var n39 = 0;

var n40 = 0; var n41 = 0; var n42 = 0; var n43 = 0; var n44 = 0;
var n45 = 0; var n46 = 0; var n47 = 0; var n48 = 0; var n49 = 0;

var n50 = 0; var n51 = 0; var n52 = 0; var n53 = 0; var n54 = 0;
var n55 = 0; var n56 = 0; var n57 = 0; var n58 = 0; var n59 = 0;

var n60 = 0; var n61 = 0; var n62 = 0; var n63 = 0; var n64 = 0;
var n65 = 0; var n66 = 0; var n67 = 0; var n68 = 0; var n69 = 0;

var n70 = 0; var n71 = 0; var n72 = 0; var n73 = 0; var n74 = 0;
var n75 = 0; var n76 = 0; var n77 = 0; var n78 = 0; var n79 = 0;

var n80 = 0; var n81 = 0; var n82 = 0; var n83 = 0; var n84 = 0;
var n85 = 0; var n86 = 0; var n87 = 0; var n88 = 0; var n89 = 0;

var n90 = 0; var n91 = 0; var n92 = 0; var n93 = 0; var n94 = 0;
var n95 = 0; var n96 = 0; var n97 = 0; var n98 = 0; var n99 = 0;

// Helper functions for getting and setting cell values
func get_cell(x int, y int) int {
    if x == 0 {
        if y == 0 { return c00; }
        if y == 1 { return c01; }
        if y == 2 { return c02; }
        if y == 3 { return c03; }
        if y == 4 { return c04; }
        if y == 5 { return c05; }
        if y == 6 { return c06; }
        if y == 7 { return c07; }
        if y == 8 { return c08; }
        if y == 9 { return c09; }
    }
    if x == 1 {
        if y == 0 { return c10; }
        if y == 1 { return c11; }
        if y == 2 { return c12; }
        if y == 3 { return c13; }
        if y == 4 { return c14; }
        if y == 5 { return c15; }
        if y == 6 { return c16; }
        if y == 7 { return c17; }
        if y == 8 { return c18; }
        if y == 9 { return c19; }
    }
    if x == 2 {
        if y == 0 { return c20; }
        if y == 1 { return c21; }
        if y == 2 { return c22; }
        if y == 3 { return c23; }
        if y == 4 { return c24; }
        if y == 5 { return c25; }
        if y == 6 { return c26; }
        if y == 7 { return c27; }
        if y == 8 { return c28; }
        if y == 9 { return c29; }
    }
    if x == 3 {
        if y == 0 { return c30; }
        if y == 1 { return c31; }
        if y == 2 { return c32; }
        if y == 3 { return c33; }
        if y == 4 { return c34; }
        if y == 5 { return c35; }
        if y == 6 { return c36; }
        if y == 7 { return c37; }
        if y == 8 { return c38; }
        if y == 9 { return c39; }
    }
    if x == 4 {
        if y == 0 { return c40; }
        if y == 1 { return c41; }
        if y == 2 { return c42; }
        if y == 3 { return c43; }
        if y == 4 { return c44; }
        if y == 5 { return c45; }
        if y == 6 { return c46; }
        if y == 7 { return c47; }
        if y == 8 { return c48; }
        if y == 9 { return c49; }
    }
    if x == 5 {
        if y == 0 { return c50; }
        if y == 1 { return c51; }
        if y == 2 { return c52; }
        if y == 3 { return c53; }
        if y == 4 { return c54; }
        if y == 5 { return c55; }
        if y == 6 { return c56; }
        if y == 7 { return c57; }
        if y == 8 { return c58; }
        if y == 9 { return c59; }
    }
    if x == 6 {
        if y == 0 { return c60; }
        if y == 1 { return c61; }
        if y == 2 { return c62; }
        if y == 3 { return c63; }
        if y == 4 { return c64; }
        if y == 5 { return c65; }
        if y == 6 { return c66; }
        if y == 7 { return c67; }
        if y == 8 { return c68; }
        if y == 9 { return c69; }
    }
    if x == 7 {
        if y == 0 { return c70; }
        if y == 1 { return c71; }
        if y == 2 { return c72; }
        if y == 3 { return c73; }
        if y == 4 { return c74; }
        if y == 5 { return c75; }
        if y == 6 { return c76; }
        if y == 7 { return c77; }
        if y == 8 { return c78; }
        if y == 9 { return c79; }
    }
    if x == 8 {
        if y == 0 { return c80; }
        if y == 1 { return c81; }
        if y == 2 { return c82; }
        if y == 3 { return c83; }
        if y == 4 { return c84; }
        if y == 5 { return c85; }
        if y == 6 { return c86; }
        if y == 7 { return c87; }
        if y == 8 { return c88; }
        if y == 9 { return c89; }
    }
    if x == 9 {
        if y == 0 { return c90; }
        if y == 1 { return c91; }
        if y == 2 { return c92; }
        if y == 3 { return c93; }
        if y == 4 { return c94; }
        if y == 5 { return c95; }
        if y == 6 { return c96; }
        if y == 7 { return c97; }
        if y == 8 { return c98; }
        if y == 9 { return c99; }
    }
    return 0; // Default case - shouldn't happen with our constraints
}

// Set a cell in the next generation grid
func set_next(x int, y int, val int) int {
    if x == 0 {
        if y == 0 { n00 = val; }
        if y == 1 { n01 = val; }
        if y == 2 { n02 = val; }
        if y == 3 { n03 = val; }
        if y == 4 { n04 = val; }
        if y == 5 { n05 = val; }
        if y == 6 { n06 = val; }
        if y == 7 { n07 = val; }
        if y == 8 { n08 = val; }
        if y == 9 { n09 = val; }
    }
    if x == 1 {
        if y == 0 { n10 = val; }
        if y == 1 { n11 = val; }
        if y == 2 { n12 = val; }
        if y == 3 { n13 = val; }
        if y == 4 { n14 = val; }
        if y == 5 { n15 = val; }
        if y == 6 { n16 = val; }
        if y == 7 { n17 = val; }
        if y == 8 { n18 = val; }
        if y == 9 { n19 = val; }
    }
    if x == 2 {
        if y == 0 { n20 = val; }
        if y == 1 { n21 = val; }
        if y == 2 { n22 = val; }
        if y == 3 { n23 = val; }
        if y == 4 { n24 = val; }
        if y == 5 { n25 = val; }
        if y == 6 { n26 = val; }
        if y == 7 { n27 = val; }
        if y == 8 { n28 = val; }
        if y == 9 { n29 = val; }
    }
    if x == 3 {
        if y == 0 { n30 = val; }
        if y == 1 { n31 = val; }
        if y == 2 { n32 = val; }
        if y == 3 { n33 = val; }
        if y == 4 { n34 = val; }
        if y == 5 { n35 = val; }
        if y == 6 { n36 = val; }
        if y == 7 { n37 = val; }
        if y == 8 { n38 = val; }
        if y == 9 { n39 = val; }
    }
    if x == 4 {
        if y == 0 { n40 = val; }
        if y == 1 { n41 = val; }
        if y == 2 { n42 = val; }
        if y == 3 { n43 = val; }
        if y == 4 { n44 = val; }
        if y == 5 { n45 = val; }
        if y == 6 { n46 = val; }
        if y == 7 { n47 = val; }
        if y == 8 { n48 = val; }
        if y == 9 { n49 = val; }
    }
    if x == 5 {
        if y == 0 { n50 = val; }
        if y == 1 { n51 = val; }
        if y == 2 { n52 = val; }
        if y == 3 { n53 = val; }
        if y == 4 { n54 = val; }
        if y == 5 { n55 = val; }
        if y == 6 { n56 = val; }
        if y == 7 { n57 = val; }
        if y == 8 { n58 = val; }
        if y == 9 { n59 = val; }
    }
    if x == 6 {
        if y == 0 { n60 = val; }
        if y == 1 { n61 = val; }
        if y == 2 { n62 = val; }
        if y == 3 { n63 = val; }
        if y == 4 { n64 = val; }
        if y == 5 { n65 = val; }
        if y == 6 { n66 = val; }
        if y == 7 { n67 = val; }
        if y == 8 { n68 = val; }
        if y == 9 { n69 = val; }
    }
    if x == 7 {
        if y == 0 { n70 = val; }
        if y == 1 { n71 = val; }
        if y == 2 { n72 = val; }
        if y == 3 { n73 = val; }
        if y == 4 { n74 = val; }
        if y == 5 { n75 = val; }
        if y == 6 { n76 = val; }
        if y == 7 { n77 = val; }
        if y == 8 { n78 = val; }
        if y == 9 { n79 = val; }
    }
    if x == 8 {
        if y == 0 { n80 = val; }
        if y == 1 { n81 = val; }
        if y == 2 { n82 = val; }
        if y == 3 { n83 = val; }
        if y == 4 { n84 = val; }
        if y == 5 { n85 = val; }
        if y == 6 { n86 = val; }
        if y == 7 { n87 = val; }
        if y == 8 { n88 = val; }
        if y == 9 { n89 = val; }
    }
    if x == 9 {
        if y == 0 { n90 = val; }
        if y == 1 { n91 = val; }
        if y == 2 { n92 = val; }
        if y == 3 { n93 = val; }
        if y == 4 { n94 = val; }
        if y == 5 { n95 = val; }
        if y == 6 { n96 = val; }
        if y == 7 { n97 = val; }
        if y == 8 { n98 = val; }
        if y == 9 { n99 = val; }
    }
    return 0;
}

// Initialize the grid with a glider pattern
func initialize_grid() int {
    // Glider pattern
    c21 = 1;
    c32 = 1;
    c33 = 1;
    c23 = 1;
    c13 = 1;
    return 0;
}

// Count the neighbors of a cell
func count_neighbors(x int, y int) int {
    var count = 0;
    var x_minus_1 = x - 1;
    var x_plus_1 = x + 1;
    var y_minus_1 = y - 1;
    var y_plus_1 = y + 1;
    
    // Check boundaries
    if x_minus_1 >= 0 {
        if y_minus_1 >= 0 {
            count = count + get_cell(x_minus_1, y_minus_1);
        }
        count = count + get_cell(x_minus_1, y);
        if y_plus_1 < height {
            count = count + get_cell(x_minus_1, y_plus_1);
        }
    }
    
    if y_minus_1 >= 0 {
        count = count + get_cell(x, y_minus_1);
    }
    if y_plus_1 < height {
        count = count + get_cell(x, y_plus_1);
    }
    
    if x_plus_1 < width {
        if y_minus_1 >= 0 {
            count = count + get_cell(x_plus_1, y_minus_1);
        }
        count = count + get_cell(x_plus_1, y);
        if y_plus_1 < height {
            count = count + get_cell(x_plus_1, y_plus_1);
        }
    }
    
    return count;
}

// Update the grid based on Game of Life rules
func update_grid() int {
    var x = 0;
    var y = 0;
    
    // For each cell, compute its next state
    while x < width {
        y = 0;
        while y < height {
            var cell = get_cell(x, y);
            var neighbors = count_neighbors(x, y);
            
            if cell == 1 {
                // Live cell logic
                if neighbors < 2 {
                    // Dies from underpopulation
                    set_next(x, y, 0);
                } else {
                    if neighbors > 3 {
                        // Dies from overpopulation
                        set_next(x, y, 0);
                    } else {
                        // Survives
                        set_next(x, y, 1);
                    }
                }
            } else {
                // Dead cell logic
                if neighbors == 3 {
                    // Cell becomes alive
                    set_next(x, y, 1);
                } else {
                    // Stays dead
                    set_next(x, y, 0);
                }
            }
            
            y = y + 1;
        }
        x = x + 1;
    }
    
    // Copy next generation to current
    c00 = n00; c01 = n01; c02 = n02; c03 = n03; c04 = n04;
    c05 = n05; c06 = n06; c07 = n07; c08 = n08; c09 = n09;
    
    c10 = n10; c11 = n11; c12 = n12; c13 = n13; c14 = n14;
    c15 = n15; c16 = n16; c17 = n17; c18 = n18; c19 = n19;
    
    c20 = n20; c21 = n21; c22 = n22; c23 = n23; c24 = n24;
    c25 = n25; c26 = n26; c27 = n27; c28 = n28; c29 = n29;
    
    c30 = n30; c31 = n31; c32 = n32; c33 = n33; c34 = n34;
    c35 = n35; c36 = n36; c37 = n37; c38 = n38; c39 = n39;
    
    c40 = n40; c41 = n41; c42 = n42; c43 = n43; c44 = n44;
    c45 = n45; c46 = n46; c47 = n47; c48 = n48; c49 = n49;
    
    c50 = n50; c51 = n51; c52 = n52; c53 = n53; c54 = n54;
    c55 = n55; c56 = n56; c57 = n57; c58 = n58; c59 = n59;
    
    c60 = n60; c61 = n61; c62 = n62; c63 = n63; c64 = n64;
    c65 = n65; c66 = n66; c67 = n67; c68 = n68; c69 = n69;
    
    c70 = n70; c71 = n71; c72 = n72; c73 = n73; c74 = n74;
    c75 = n75; c76 = n76; c77 = n77; c78 = n78; c79 = n79;
    
    c80 = n80; c81 = n81; c82 = n82; c83 = n83; c84 = n84;
    c85 = n85; c86 = n86; c87 = n87; c88 = n88; c89 = n89;
    
    c90 = n90; c91 = n91; c92 = n92; c93 = n93; c94 = n94;
    c95 = n95; c96 = n96; c97 = n97; c98 = n98; c99 = n99;
    
    return 0;
}

// Display the grid
func display_grid() int {
    var x = 0;
    var y = 0;
    
    // Print top border
    print '+';
    var i = 0;
    while i < width {
        print '-';
        i = i + 1;
    }
    print '+';
    print '\n';
    
    // Print grid cells
    while y < height {
        print '|';
        x = 0;
        while x < width {
            if get_cell(x, y) == 1 {
                print '*';
            } else {
                print ' ';
            }
            x = x + 1;
        }
        print '|';
        print '\n';
        y = y + 1;
    }
    
    // Print bottom border
    print '+';
    i = 0;
    while i < width {
        print '-';
        i = i + 1;
    }
    print '+';
    print '\n';
    
    return 0;
}

// Run the simulation for a number of generations
func run_simulation(generations int) int {
    initialize_grid();
    
    var gen = 0;
    while gen < generations {
        print 'G';  // G for generation.
        print gen;
        print '\n';
        display_grid();
        update_grid();
        gen = gen + 1;
        print '\n';
    }
    
    return 0;
}

// Start the simulation
run_simulation(20);