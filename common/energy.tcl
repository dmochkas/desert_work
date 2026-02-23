
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