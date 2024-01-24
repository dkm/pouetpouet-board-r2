// Based on keyseebee plate.scad
// https://github.com/TeXitoi/keyseebee/tree/master/cad
// Modified for https://github.com/dkm/pouetpouet-board-r2

switch_hole=14.0;// by spec should be 14, can be adjusted for printer imprecision
thickness=2;// plate thickness

m2_hole=2;

linear_extrude(thickness) // uncomment for 3D model
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
          m2_hole_placement() translate([inter_switch/2, -inter_switch/2]) circle(m2_hole);
     }
}
