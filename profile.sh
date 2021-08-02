#!/bin/sh
valgrind --tool=callgrind --dump-instr=yes --simulate-cache=yes --collect-jumps=yes zig-out/bin/zig_ray
