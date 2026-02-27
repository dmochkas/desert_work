
proc csvExporter {dataArg sep} {
    upvar 1 $dataArg data

    set keys [dict keys [lindex $data 0]]
    set header [join $keys $sep]

    puts "$header"
    foreach dataRow $data {
        set row ""
        foreach key $keys {
            append row [dict get $dataRow $key] $sep
        }
        set row [string range $row 0 end-1]
        puts "$row"
    }
}