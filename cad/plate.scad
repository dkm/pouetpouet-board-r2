// Based on keyseebee plate.scad
// https://github.com/TeXitoi/keyseebee/tree/master/cad
// Modified for https://github.com/dkm/pouetpouet-board-r2

switch_hole=14.0;// by spec should be 14, can be adjusted for printer imprecision
thickness=1.6;// plate thickness

linear_extrude(thickness) // uncomment for 3D model
plate();

// Corresponds to the switch footprint in KiCad.
inter_switch=19.05;

// Repeats argument on the 12*4 matrix
module key_placement() {
     for (i=[0:11]) for (j=[0:4]) translate([(i-1)*inter_switch, -(j-1)*inter_switch]) children();
}

module outline() {
          hull() key_placement() square(inter_switch, center=true);
}

module plate() {
     difference() {
          outline();
          key_placement() square(switch_hole, center=true);
     }
}
