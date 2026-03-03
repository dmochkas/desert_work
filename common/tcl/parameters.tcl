
proc parseBashParams {paramOrder} {
    global opt argv

    for {set i 0} {$i < [llength $paramOrder]} {incr i} {
        set tmp [lindex $argv $i]
        if {$tmp != 0 && $tmp != ""} {
            set opt([lindex $paramOrder $i]) $tmp
        }
    }
}