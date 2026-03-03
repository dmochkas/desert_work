#####################
# Library Loading   #
#####################
load libMiracle.so
load libMiracleBasicMovement.so
load libmphy.so
load libmmac.so
load libuwip.so
load libuwstaticrouting.so
load libuwmll.so
load libuwudp.so
load libuwcbr.so
load libuwcsmaaloha.so
load libuwinterference.so
load libUwmStd.so
load libuwphy_clmsgs.so
load libuwstats_utilities.so
load libuwphysical.so
load libuwahoi_phy.so

#############################
# NS-Miracle initialization #
#############################
set ns [new Simulator]
$ns use-Miracle

source "../common/get-config.tcl"
source "../common/parameters.tcl"
source "../common/positioning.tcl"
source "../common/communication.tcl"
source "../common/exporters.tcl"

load-config "added_security_settings.yaml"
load-positions "dag_position_6.yaml"

set CSV_SEPARATOR ,

##################
# Tcl variables  #
##################
set opt(rngstream)	1

if {$opt(bash_parameters)} {
    parseBashParams $opt(bashParamOrder)
}

set modemConfig       [dict get $opt(modems) $opt(modem)]
set opt(simDuration)  [expr $opt(stoptime) - $opt(starttime)]
set opt(lambda)       [getRateFromSizeRateAndDuty $opt(frameSize) [dict get $modemConfig bitrate] $opt(dutyCycle)]
set opt(cbrPeriod)    [ratePeriod $opt(lambda)]
# INFO: ip and udp layers give 4 bytes of overhead --- typical constrained IoT overhead
set opt(payloadSize)      [expr $opt(frameSize) - $opt(headerSize)]

if {$opt(ACK_Active)} {
    set opt(ack_mode)           "setAckMode"
} else {
    set opt(ack_mode)           "setNoAckMode"
}

for {set k 0} {$k < $opt(rngstream)} {incr k} {
	$defaultRNG next-substream
}

if {$opt(trace_files)} {
	set opt(tracefilename) "./test_uwhermesphy_simple.tr"
	set opt(tracefile) [open $opt(tracefilename) w]
	set opt(cltracefilename) "./test_uwhermesphy_simple.cltr"
	set opt(cltracefile) [open $opt(tracefilename) w]
} else {
	set opt(tracefilename) "/dev/null"
	set opt(tracefile) [open $opt(tracefilename) w]
	set opt(cltracefilename) "/dev/null"
	set opt(cltracefile) [open $opt(cltracefilename) w]
}

#MPropagation/Underwater set practicalSpreading_ 1.8
#MPropagation/Underwater set debug_              0
#MPropagation/Underwater set windspeed_          1

#Mpropagation/Underwater set windspeed_ 20
#Mpropagation/Underwater set shipping_ 1

#########################
# Module Configuration  #
#########################
# TODO: Compute pktsize
# TODO: Added security is not required
Module/UW/CBR set packetSize_          $opt(payloadSize)
Module/UW/CBR set period_              $opt(cbrPeriod)

Module/UW/PHYSICAL  set BitRate_                    [dict get $modemConfig bitrate]
Module/UW/PHYSICAL  set MaxTxSPL_dB_                [dict get $modemConfig txPressure]
Module/UW/PHYSICAL  set MaxTxRange_                 [dict get $modemConfig range]

set channel [new Module/UnderwaterChannel]
set propagation [new MPropagation/Underwater]
set data_mask [new MSpectralMask/Rect]
$data_mask setFreq       [dict get $modemConfig freq]
$data_mask setBandwidth  [dict get $modemConfig bandwidth]


#####################
# Node Configuration #
#####################
set sinkId 254

set firstLevelRelays [list 1 2]
set secondLevelRelays [list 3 4 5 6]
set relayIds [list 1 2 3 4 5 6]
set nRelay [llength $relayIds]
foreach relayId $relayIds {
    createNode $relayId false
}

# TODO: Works only with multiples of parent
set nSensors 32
set sensorIds [list]
for {set i [expr $nRelay + 1]} {$i <= [expr $nRelay + $nSensors]} {incr i} {
    createNode $i false
    lappend sensorIds $i
}

createNode $sinkId true

assignPositionsFromConfig position positions

set sinkIP [$ipif($sinkId) addr]
set sinkMAC [$mac($sinkId) addr]

foreach firstLevelRelay $firstLevelRelays {
    $mll($firstLevelRelay) addentry $sinkIP $sinkMAC
    $ipr($firstLevelRelay) addRoute $sinkIP $sinkIP
}

set clusterSize [expr $nSensors / [llength $secondLevelRelays]]
set i 0
foreach secondLevelRelay $secondLevelRelays {
    set relayI [expr $i * [llength $firstLevelRelays] / [llength $secondLevelRelays]]
    set relayIP [$ipif([lindex $firstLevelRelays $relayI]) addr]
    set relayMAC [$mac([lindex $firstLevelRelays $relayI]) addr]
    $mll($secondLevelRelay) addentry $relayIP $relayMAC
    $ipr($secondLevelRelay) addRoute $sinkIP $relayIP

    # TODO: Consider last sensors
    placeUniformlyAtDBelowParent [lrange $sensorIds [expr $i*$clusterSize] [expr $i*$clusterSize+$clusterSize]] $secondLevelRelay position 1000 500
    set i [expr $i + 1]
}

for {set i 0} {$i < [llength $sensorIds]} {incr i} {
    set sensor [lindex $sensorIds $i]
    set relayI [expr $i / $clusterSize]
    set relayIP [$ipif([lindex $secondLevelRelays $relayI]) addr]
    set relayMAC [$mac([lindex $secondLevelRelays $relayI]) addr]
    set sinkPort $portnum_sink($sinkId,$sensor)

    $mll($sensor) addentry $relayIP $relayMAC
    $ipr($sensor) addRoute $sinkIP $relayIP
    $cbr($sensor) set destAddr_ $sinkIP
    $cbr($sensor) set destPort_ $sinkPort

    $ns at $opt(starttime)    "$cbr($sensor) start"
    $ns at $opt(stoptime)     "$cbr($sensor) stop"
}