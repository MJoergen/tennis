#! /usr/bin/env python

import math
import sys

def unit_vector_base(x, y):
    l = math.sqrt(x*x + y*y)
    return (x/l, y/l)

def unit_vector_fpga(x, y):
    # This uses the Cordic algorithm to convert a vector into a unit vector
    assert x >= 0
    ux = 0.6072529350088812561694
    uy = 0.0
    coef = 1.0
    for s in range(0, 30):
        alpha = math.atan(coef)
        #print(f"x={x:.4f}, y={y:7.4f}, ux={ux:.4f}, uy={uy:.4f}, coef={coef:.4f}, alpha={alpha:.4f}, ca={math.cos(alpha):.4f}, sa={math.sin(alpha):.4f}")
        if y > 0:
            (x,y) = (x+y*coef, y-x*coef)
            (ux,uy) = (ux-uy*coef, uy+ux*coef)
        else:
            (x,y) = (x-y*coef, y+x*coef)
            (ux,uy) = (ux+uy*coef, uy-ux*coef)
        coef *= 0.5

    return (ux, uy)

d2_max = -1.0
for x_r in range (1, 11):
    x = x_r / 10.0
    for y_r in range (-100, 101):
        y = y_r / 100.0
        b = unit_vector_base(x, y)
        f = unit_vector_fpga(x, y)
        d = [b[0] - f[0], b[1] - f[1]]
        d2 = math.sqrt(d[0]*d[0] + d[1]*d[1])
        if d2 > d2_max:
            print(x, y, d2)
            d2_max = d2

print("Done")

