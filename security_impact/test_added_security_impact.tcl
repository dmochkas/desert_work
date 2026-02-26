######################################
# Flags to enable or disable options #
######################################
set opt(verbose) 			1
set opt(trace_files)		0
set opt(bash_parameters) 	1

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

# NS-Miracle initialization #
#############################
# You always need the following two lines to use the NS-Miracle simulator
set ns [new Simulator]
$ns use-Miracle

source "../common/get-config.tcl"
source "../common/parameters.tcl"
source "../common/positioning.tcl"

load-config "added_security_settings.yaml"
load-positions "dag_position_6.yaml"

##################
# Tcl variables  #
##################
set opt(txduration)         [expr $opt(stoptime) - $opt(starttime)] ;# Duration of the simulation

set opt(txpower)            156.0  ;#Power transmitted in dB re uPa
#set opt(txpower)            174.0  ;#Power transmitted in dB re uPa
set opt(max_range)          300    ;# Max transmission range

# TODO: Compute
set opt(cbr_period)         10000
set opt(rngstream)	1

if {$opt(bash_parameters)} {
    set opt(finish_mode)        "export" ;# diag or export
    parseBashParams $opt(bashParamOrder)
    puts "$opt(rngstream)"
    puts "$opt(modem)"
    set value [dict get $opt(modems) $opt(modem)]
    puts "$value"
} else {
    set opt(finish_mode)        "diag" ;# diag or export
}

set modemConfig [dict get $opt(modems) $opt(modem)]

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
set opt(pktsize) 32
Module/UW/CBR set packetSize_          $opt(pktsize)
# TODO: Compute period
Module/UW/CBR set period_              $opt(cbr_period)

Module/UW/PHYSICAL  set BitRate_                    [dict get $modemConfig bitrate]
Module/UW/PHYSICAL  set MaxTxSPL_dB_                [dict get $modemConfig txPressure]
Module/UW/PHYSICAL  set MaxTxRange_                 [dict get $modemConfig range]

set channel [new Module/UnderwaterChannel]
set propagation [new MPropagation/Underwater]
set data_mask [new MSpectralMask/Rect]
$data_mask setFreq       [dict get $modemConfig freq]
$data_mask setBandwidth  [dict get $modemConfig bandwidth]

################################
# Procedure(s) to create nodes #
################################
proc createNode { id sink_flag } {

    global channel propagation data_mask ns cbr cbr_sink position node udp portnum portnum_sink ipr ipif channel_estimator
    global phy posdb opt rvposx rvposy rvposz mhrouting mll mac woss_utilities woss_creator db_manager
    global node_coordinates interf_data
    global sensorIds nSensors relayIds

    if {$id > 254} {
		puts "Max id value is 254"
		exit
    }

    set node($id) [$ns create-M_Node $opt(tracefile) $opt(cltracefile)]

    if {$sink_flag} {
        foreach node_id $sensorIds {
            set cbr_sink($id,$node_id)  [new Module/UW/CBR]
        }
    } else {
        set cbr($id)  [new Module/UW/CBR]
    }

    set udp($id)  [new Module/UW/UDP]
    set ipr($id)  [new Module/UW/StaticRouting]
    set ipif($id) [new Module/UW/IP]
    set mll($id)  [new Module/UW/MLL]
    set mac($id)  [new Module/UW/CSMA_ALOHA]
    set phy($id) [new Module/UW/PHYSICAL]

    #$ipr($id) setLog 3 "log_ip.out"
    #$udp($id) setLog 3 "log_udp.out"
    #$cbr($id) setLog 3 "log_cbr.out"

    if {$sink_flag} {
        foreach node_id $sensorIds {
            $node($id) addModule 7 $cbr_sink($id,$node_id) 0 "CBR"
        }
    } else {
	    $node($id) addModule 7 $cbr($id)   1  "CBR"
    }

    $node($id) addModule 6 $udp($id)   1  "UDP"
    $node($id) addModule 5 $ipr($id)   1  "IPR"
    $node($id) addModule 4 $ipif($id)  1  "IPF"
    $node($id) addModule 3 $mll($id)   1  "MLL"
    $node($id) addModule 2 $mac($id)   1  "MAC"
    $node($id) addModule 1 $phy($id)   0  "PHY"

	if {$sink_flag} {
        foreach node_id $sensorIds {
            $node($id) setConnection $cbr_sink($id,$node_id)  $udp($id)      0
            set portnum_sink($id,$node_id) [$udp($id) assignPort $cbr_sink($id,$node_id)]
        }
	} else {
        $node($id) setConnection $cbr($id)   $udp($id)   1
        set portnum($id) [$udp($id) assignPort $cbr($id)]
	}
    $node($id) setConnection $udp($id)      $ipr($id)   1
    $node($id) setConnection $ipr($id)      $ipif($id)  1
    $node($id) setConnection $ipif($id)     $mll($id)   1
    $node($id) setConnection $mll($id)      $mac($id)   1
    $node($id) setConnection $mac($id)      $phy($id)   1
    $node($id) addToChannel  $channel       $phy($id)   1

    #Set the IP address of the node
    set ip_addr_value [expr $id]
    $ipif($id) addr $ip_addr_value

    set position($id) [new "Position/BM"]
    $node($id) addPosition $position($id)
    set posdb($id) [new "PlugIn/PositionDB"]
    $node($id) addPlugin $posdb($id) 20 "PDB"
    $posdb($id) addpos [$ipif($id) addr] $position($id)

    #Interference model
    set interf_data($id)  [new "Module/UW/INTERFERENCE"]
    $interf_data($id) set maxinterval_ $opt(maxinterval_)
    $interf_data($id) set debug_       0

	#Propagation model
    $phy($id) setPropagation $propagation

    $phy($id) setSpectralMask $data_mask
    $phy($id) setInterference $interf_data($id)
    $phy($id) setInterferenceModel "MEANPOWER";

    $mac($id) $opt(ack_mode)
    $mac($id) initialize
}

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

###################
# Final Procedure #
###################
proc finish {} {
    global ns opt outfile modemConfig
    global mac propagation cbr_sink mac_sink phy phy_data_sink channel db_manager propagation
    global node_coordinates position
    global ipr_sink ipr ipif udp cbr phy phy_data_sink
    global node_stats tmp_node_stats sink_stats tmp_sink_stats
    global sinkId sensorIds relayIds nSensors

    if ($opt(verbose)) {
        puts "---------------------------------------------------------------------"
        puts "Simulation summary"
        puts "number of sensors  : $opt(nSensors)"
        puts "packet size      : $opt(pktsize) byte"
        puts "cbr period       : $opt(cbr_period) s"
        puts "simulation length: $opt(txduration) s"
        puts "tx pressure      : [dict get $modemConfig txPressure] dB"
        puts "tx power         : [dict get $modemConfig txPower] dB"
        puts "tx frequency     : [dict get $modemConfig freq] Hz"
        puts "tx bandwidth     : [dict get $modemConfig bandwidth] Hz"
        puts "bitrate          : [dict get $modemConfig bitrate] bps"
        puts "range          : [dict get $modemConfig range] bps"
        if {$opt(ack_mode) == "setNoAckMode"} {
            puts "ACKNOWLEDGEMENT   : disabled"
        } else {
            puts "ACKNOWLEDGEMENT   : active"
        }
        puts "---------------------------------------------------------------------"
    }
    set sum_cbr_throughput     0
    set sum_per                0
    set sum_cbr_sent_pkts      0.0
    set sum_cbr_rcv_pkts       0.0
    set sum_rtx                0.0
    set cbr_throughput         0.0
    set cbr_per                0.0

    foreach node_id $sensorIds {
        set position_x              [$position($node_id) getX_]
        set position_y              [$position($node_id) getY_]
        set position_z              [$position($node_id) getZ_]
        set cbr_throughput              [$cbr_sink($sinkId,$node_id)  getthr]
        set cbr_per                     [$cbr_sink($sinkId,$node_id)  getper]
        set cbr_rcv_pkts                [$cbr_sink($sinkId,$node_id) getrecvpkts]
        set cbr_sent_pkts               [$cbr($node_id) getsentpkts]

        puts "node($node_id) X     : $position_x"
        puts "node($node_id) Y     : $position_y"
        puts "node($node_id) Z     : $position_z"
        puts "cbr($node_id) Packets sent   : $cbr_sent_pkts"
        puts "cbr($node_id) Packets sent   : [$cbr($node_id) getrecvpkts]"
        puts "cbr_sink($sinkId,$node_id) Throughput     : $cbr_throughput"
        puts "cbr_sink($sinkId, $node_id) Packets rcv   : $cbr_rcv_pkts"
        puts "cbr_sink($sinkId,$node_id) PER            : $cbr_per       "
        puts ""

        set sum_cbr_throughput [expr $sum_cbr_throughput + $cbr_throughput]
        set sum_cbr_sent_pkts [expr $sum_cbr_sent_pkts + $cbr_sent_pkts]
        set sum_cbr_rcv_pkts  [expr $sum_cbr_rcv_pkts + $cbr_rcv_pkts]
    }

    set ipheadersize        [$ipif(1) getipheadersize]
    set udpheadersize       [$udp(1) getudpheadersize]
    set cbrheadersize       [$cbr(1) getcbrheadersize]
    set pdr                 [expr $sum_cbr_sent_pkts > 0 ? ($sum_cbr_rcv_pkts / $sum_cbr_sent_pkts * 100) : 100.0]

    if ($opt(verbose)) {
        puts "Mean Throughput           : [expr $sum_cbr_throughput / $nSensors]"
        puts "Sent Packets              : $sum_cbr_sent_pkts"
        puts "Received Packets          : $sum_cbr_rcv_pkts"
        puts "Packet Delivery Ratio     : $pdr"
        puts "IP Pkt Header Size        : $ipheadersize"
        puts "UDP Header Size           : $udpheadersize"
        puts "CBR Header Size           : $cbrheadersize"
        if {$opt(ack_mode) == "setAckMode"} {
            puts "MAC-level average retransmissions per node : [expr $sum_rtx/($opt(nn))]"
        }
        puts "---------------------------------------------------------------------"
    }

    $ns flush-trace
    close $opt(tracefile)
}

$ns at [expr $opt(stoptime) + 250.0]  "finish; $ns halt"

$ns run
