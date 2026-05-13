#! /usr/bin/env python

import math

RADIUS = 32
for i in range(RADIUS-1,-RADIUS-1,-1):
    x = i + 0.01
    y = int(math.sqrt(RADIUS*RADIUS-x*x)) + 1
    s = "0" * (RADIUS-y) + "1" * y + "1" * (y-1) + "0" * (RADIUS-y+1)
    print(f"{RADIUS-1-i:2d} => \"{s}\",")

