// Based on keyseebee plate.scad
// https://github.com/TeXitoi/keyseebee/tree/master/cad
// Modified for https://github.com/dkm/pouetpouet-board-r2

// Configuration
// You may need to adjust, depending on the actual size of 
// your screws/standoffs and the printer/building process
// imprecision.

// by spec should be 14, can be adjusted for printer imprecision
// 14 => needs force to "click" the switch
switch_hole=14.2;

// Plate thickness
// The thicker, the stronger...
// The plate + standoff = 5mm
// With 3mm standoff, plate must be 2mm.
thickness=2;

// Better be a bit smaller than bigger. May depend on your
// standoff sizes.
// 2.2 => norm, but too large
// 2   => still too large
m2_hole=1.8;

linear_extrude(thickness)
plate();

// Corresponds to the switch footprint in KiCad.
inter_switch=19.05;

// Repeats argument on the 12*4 matrix
module key_placement() {
     for (i=[0:11]) for (j=[0:4]) translate([(i-1)*inter_switch, -(j-1)*inter_switch]) children();
}

module m2_hole_placement() {
     for (i=[0:11]) for (j=[0:4])
        if ((i==0 && j == 0)
            || (i==0 && j == 3)
            || (i==5 && j == 0)
            || (i==5 && j == 3)
            || (i==10 && j == 0)
            || (i==10 && j == 3))
        
            translate([(i-1)*inter_switch, -(j-1)*inter_switch]) children();
}

module outline() {
          hull() key_placement() square(inter_switch, center=true);
}

module plate() {
     difference() {
          outline();
          key_placement() square(switch_hole, center=true);
          m2_hole_placement() translate([inter_switch/2, -inter_switch/2]) circle(m2_hole, $fn=30);
     }
}
