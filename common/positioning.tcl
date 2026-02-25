
proc placeUniformlyAtDBelowParent {nodes parent positionsArg commR L} {
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
        set randX [expr $parentX + $randR*cos($theta)]
        set randY [expr $parentY + $randR*sin($theta)]

        $positions($nodeId) setX_ $randX
        $positions($nodeId) setY_ $randY
        $positions($nodeId) setZ_ $newDepth
    }
}

proc assignPositionsFromConfig {positionsArg posConfigArg} {
    upvar 1 $positionsArg positions
    upvar 1 $posConfigArg posConfig

    foreach key [array names posConfig] {
        set value $posConfig($key)
        set id         [lindex [split $key ","] 0]
        set coordinate [lindex [split $key ","] 1]

        if {$coordinate == "x"} {
            $positions($id) setX_ $value
        } elseif {$coordinate == "y"} {
           $positions($id) setY_ $value
        } elseif {$coordinate == "z"} {
            $positions($id) setZ_ $value
        }
    }
}