
set BYTE_BITS 8

proc getRateFromSizeRateAndDuty {frameSizeBytes bitrate dutyCycle} {
    global BYTE_BITS

    return [expr 0.01 * ($dutyCycle*$bitrate)/($frameSizeBytes*$BYTE_BITS)]
}

proc ratePeriod {value} {
    return [expr 1.0/$value]
}