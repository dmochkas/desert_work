
set CSV_CONTENT_SEPARATOR "##########"

proc csvOptExporter {exportOptsArg sep} {
    global opt

    upvar 1 $exportOptsArg exportOpts

    set header ""
    set row ""
    foreach key $exportOpts {
        append header $key $sep
        append row $opt($key) $sep
    }
    set header [string range $header 0 end-1]
    set row [string range $row 0 end-1]
    puts "$header"
    puts "$row"
}

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