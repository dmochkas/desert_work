
proc getRateFromSizeRateAndDuty {frameSizeBytes bitrate dutyCycle} {
    global consts

    return [expr 0.01 * ($dutyCycle*$bitrate)/($frameSizeBytes*$consts(BYTE_BITS))]
}

proc ratePeriod {value} {
    return [expr 1.0/$value]
}