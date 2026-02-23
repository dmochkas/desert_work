
proc placeUniformlyAtLBelowParent {nodes parent positionsArg commR L} {
    global defaultRNG

    upvar 1 $positionsArg positions

    set parentX [$positions($parent) getX_]
    set parentY [$positions($parent) getY_]
    set parentZ [$positions($parent) getZ_]

    set pi [expr {acos(-1)}]
    set newDepth [expr $parentZ - $L]
    set r        [expr sqrt(pow($commR, 2)-pow($L, 2))]

    foreach nodeId $nodes {
        set u1    [$defaultRNG uniform 0 1]
        set u2    [$defaultRNG uniform 0 1]
        set theta [expr 2*$pi*$u1]
        set randR [expr $r*sqrt($u2)]
        set randX [expr $randR*cos($theta)]
        set randY [expr $randR*sin($theta)]

        $positions($nodeId) setX_ $randX
        $positions($nodeId) setY_ $randY
        $positions($nodeId) setZ_ $newDepth
    }
}