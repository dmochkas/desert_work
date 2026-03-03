
proc computeTotalConsumption {phy idlePower startTime {stopTime ""}} {
    global ns

    if {$stopTime == ""} {
        set stopTime [$ns now]
    }

    set txConsumption [$phy getConsumedEnergyTx]
    set txDuration    [$phy getTxTime]
    set rxConsumption [$phy getConsumedEnergyRx]
    set rxDuration    [$phy getRxTime]
    set duration      [expr $stopTime - $startTime]

    return [expr $txConsumption + $rxConsumption + ($duration - ($txDuration + $rxDuration))*$idlePower]
}

proc computeTxConsumption {phy idlePower startTime {stopTime ""}} {
    global ns

    if {$stopTime == ""} {
        set stopTime [$ns now]
    }

    set txConsumption [$phy getConsumedEnergyTx]
    set txDuration    [$phy getTxTime]
    set duration      [expr $stopTime - $startTime]

    return [expr $txConsumption + ($duration - $txDuration)*$idlePower]
}

proc computeSensorConsumption {cbr frameSize modemConfig startTime {stopTime ""}} {
    global ns consts

    if {$stopTime == ""} {
        set stopTime [$ns now]
    }

    set bitrate [dict get $modemConfig bitrate]
    set flyTime [expr 1.0*$frameSize * $consts(BYTE_BITS) / $bitrate]
    set txPower [dict get $modemConfig txPower]
    set txCount [$cbr getsentpkts]
    set txDuration    [expr $txCount*$flyTime]
    set txConsumption    [expr $txDuration*$txPower]
    set rxPower [dict get $modemConfig rxPower]
    set rxCount [$cbr getrecvpkts]
    set rxDuration    [expr $rxCount*$flyTime]
    set rxConsumption [expr $rxDuration*$rxPower]
    set idlePower [dict get $modemConfig idlePower]
    set duration      [expr $stopTime - $startTime]

    return [expr $txConsumption + $rxConsumption + ($duration - ($txDuration + $rxDuration))*$idlePower]
}
