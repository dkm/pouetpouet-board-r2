// Based on keyseebee plate.scad
// https://github.com/TeXitoi/keyseebee/tree/master/cad
// Modified for https://github.com/dkm/pouetpouet-board

switch_hole=14.0;// by spec should be 14, can be adjusted for printer imprecision
thickness=1.6;// plate thickness, for 3D rendering

linear_extrude(thickness) // uncomment for 3D model
plate();

inter_switch=19.00;
d=2.54;

module key_placement_without_extreme() {
     for (i=[0:11]) for (j=[0:4]) translate([(i-1)*inter_switch, -(j-1)*inter_switch]) children();
}


module key_placement() {
     key_placement_without_extreme() children();
}

module outline() {
          hull() key_placement_without_extreme() square(inter_switch, center=true);
}

module plate() {
     difference() {
          outline();
          key_placement() square([switch_hole, switch_hole], center=true);
     }
}
