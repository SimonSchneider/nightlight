// 2D icon profiles. Both are sized to fit within a circle of diameter d.

module sun_2d(d) {
    r    = d / 2;
    core = r * 0.60;
    union() {
        circle(r = core);
        for (i = [0 : 11])
            rotate(i * 30)
                translate([0, core - 0.5])
                    polygon([[-r * 0.09, 0],
                             [ r * 0.09, 0],
                             [ 0,        r * 0.40]]);
    }
}

module moon_2d(d) {
    r = d / 2;
    // A fat crescent. Thin crescents light unevenly and print poorly at this scale.
    rotate(-30)
        difference() {
            circle(r = r);
            translate([r * 0.46, 0]) circle(r = r * 0.82);
        }
}
