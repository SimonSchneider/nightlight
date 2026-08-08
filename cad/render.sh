#!/usr/bin/env bash
# Export print-ready STLs and preview PNGs.
set -euo pipefail

SCAD="openscad"
cd "$(dirname "$0")"
mkdir -p stl preview

fail=0
for part in body backplate coupon; do
    echo "--- $part"
    if ! "$SCAD" -o "stl/${part}.stl" "${part}.scad" 2> "preview/${part}.log"; then
        echo "RENDER FAILED: $part"; fail=1; continue
    fi
    if grep -qiE "2-manifold|self-intersect|\bERROR\b" "preview/${part}.log"; then
        echo "GEOMETRY PROBLEM: $part — print services may reject this"; fail=1
    fi
    # A near-empty STL means the render "succeeded" but produced nothing.
    if [ "$(stat -f%z "stl/${part}.stl")" -lt 1024 ]; then
        echo "EMPTY STL: $part"; fail=1
    fi
    "$SCAD" --camera=0,0,0,55,0,25,320 --imgsize=1000,700 \
            -o "preview/${part}.png" "${part}.scad" 2>/dev/null
done

exit $fail
