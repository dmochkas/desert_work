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
load libuwcbrwr.so
load libuwaloha.so
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

source "../common/tcl/consts.tcl"
source "../common/tcl/energy.tcl"
source "../common/tcl/get-config.tcl"
source "../common/tcl/communication.tcl"

load-config "../common/settings/basic_settings.yaml"
load-config "local_settings.yaml"

##################
# Tcl variables  #
##################
set opt(pktsize)            20 ;# Pkt sike in byte, excluding ip and udp header

set opt(cbr_period) [ratePeriod $opt(cbr_rate)]
set opt(rngstream)	1

if {$opt(bash_parameters)} {
    set opt(finish_mode)        "export" ;# diag or export
    set opts(0) rngstream
    set opts(1) nn
    set opts(2) cbr_period
    set opts(3) sink_mode
    set opts(4) finish_mode
    for {set i 0} {$i < [array size opts]} {incr i} {
        set tmp [lindex $argv $i]
        if {$tmp != 0 && $tmp != ""} {
            set opt($opts($i)) $tmp
        }
    }
}

set modemConfig [dict get $opt(modems) $opt(modem)]
set opt(frameSize) [expr $opt(pktsize) + $opt(headerSize)]
set opt(txduration)         [expr $opt(stoptime) - $opt(starttime)] ;# Duration of the simulation


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

set channel [new Module/UnderwaterChannel]
set propagation [new MPropagation/Underwater]
set data_mask [new MSpectralMask/Rect]
$data_mask setFreq       [dict get $modemConfig freq]
$data_mask setBandwidth  [dict get $modemConfig bandwidth]

#########################
# Module Configuration  #
#########################
# Module/UW/CBR set packetSize_          $opt(pktsize)
# Module/UW/CBR set period_              $opt(cbr_period)

Module/UW/CBRWR set packetSize_          $opt(pktsize)
Module/UW/CBRWR set period_              $opt(cbr_period)
Module/UW/CBRWR set with_response_rate   0.2

# Module/UW/MLL set debug_ 100

Module/UW/PHYSICAL  set BitRate_                    [dict get $modemConfig bitrate]
Module/UW/PHYSICAL  set AcquisitionThreshold_dB_    15.0
Module/UW/PHYSICAL  set RxSnrPenalty_dB_            0
Module/UW/PHYSICAL  set TxSPLMargin_dB_             0
Module/UW/PHYSICAL  set MaxTxSPL_dB_                [dict get $modemConfig txPressure]
Module/UW/PHYSICAL  set MinTxSPL_dB_                10
Module/UW/PHYSICAL  set MaxTxRange_                 [dict get $modemConfig range]
Module/UW/PHYSICAL  set tx_power_consumption_       [dict get $modemConfig txPower]
Module/UW/PHYSICAL  set rx_power_consumption_       [dict get $modemConfig rxPower]
Module/UW/PHYSICAL  set PER_target_                 0
Module/UW/PHYSICAL  set CentralFreqOptimization_    0
Module/UW/PHYSICAL  set BandwidthOptimization_      0
Module/UW/PHYSICAL  set SPLOptimization_            0
Module/UW/PHYSICAL  set debug_                      0

################################
# Procedure(s) to create nodes #
################################
proc createNode { id } {

    global channel propagation data_mask ns cbr position node udp portnum ipr ipif channel_estimator
    global phy posdb opt rvposx rvposy rvposz mhrouting mll mac woss_utilities woss_creator db_manager
    global node_coordinates interf_data
    global node_ids

    if {$id > 254} {
		puts "Max id value is 254"
		exit
    }

    set node($id) [$ns create-M_Node $opt(tracefile) $opt(cltracefile)]

    set cbr($id)  [new Module/UW/CBRWR]
    set udp($id)  [new Module/UW/UDP]
    set ipr($id)  [new Module/UW/StaticRouting]
    set ipif($id) [new Module/UW/IP]
    set mll($id)  [new Module/UW/MLL]
    # set rep($id)  [new Module/UW/REPL]
    set mac($id)  [new Module/UW/ALOHA]
    #set phy($id)  [new Module/UW/AHOI/PHY]
    set phy($id) [new Module/UW/PHYSICAL]

    #$phy($id) setLog 3 "log.out"
    #$ipr($id) setLog 3 "log_ip.out"
    #$udp($id) setLog 3 "log_udp.out"
    #$cbr($id) setLog 3 "log_cbr.out"

	$node($id) addModule 7 $cbr($id)   1  "CBRWR"
    $node($id) addModule 6 $udp($id)   1  "UDP"
    $node($id) addModule 5 $ipr($id)   1  "IPR"
    $node($id) addModule 4 $ipif($id)  1  "IPF"
    $node($id) addModule 3 $mll($id)   1  "MLL"
    # $node($id) addModule 3 $rep($id)   1  "REP"
    $node($id) addModule 2 $mac($id)   1  "MAC"
    $node($id) addModule 1 $phy($id)   0  "PHY"

    $node($id) setConnection $cbr($id)   $udp($id)   1
    set portnum($id) [$udp($id) assignPort $cbr($id)]
    $node($id) setConnection $udp($id)      $ipr($id)   1
    $node($id) setConnection $ipr($id)      $ipif($id)  1
    $node($id) setConnection $ipif($id)     $mll($id)   1
    $node($id) setConnection $mll($id)      $mac($id)   1
    # $node($id) setConnection $rep($id)      $mac($id)   1
    $node($id) setConnection $mac($id)      $phy($id)   1
    $node($id) addToChannel  $channel       $phy($id)   1

    #Set the IP address of the node
    set ip_addr_value [expr $id + 1]
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
    $phy($id) setInterferenceModel "MEANPOWER"

    $mac($id) $opt(ack_mode)
    $mac($id) initialize
}

#####################
# Node Configuration #
#####################
set srcId 0
set dstId 1

set node_ids [list]
lappend node_ids $srcId
lappend node_ids $dstId

createNode $srcId
$position($srcId) setX_ 0
$position($srcId) setY_ 0
$position($srcId) setZ_ -1

createNode $dstId
$position($dstId) setX_ 100
$position($dstId) setY_ 0
$position($dstId) setZ_ -1

set srcIP [$ipif($srcId) addr]
set dstIP [$ipif($dstId) addr]
# set appPort [$udp($dstId) assignPort $cbr($srcId)]
$mll($srcId) addentry $dstIP [$mac($dstId) addr]
$mll($dstId) addentry $srcIP [$mac($srcId) addr]
$ipr($srcId) addRoute $dstIP $dstIP
$ipr($dstId) addRoute $srcIP $srcIP


$cbr($srcId) set destAddr_ $dstIP
$cbr($srcId) set destPort_ $portnum($dstId)

#####################
# Start/Stop Timers #
#####################
$ns at $opt(starttime)    "$cbr($srcId) start"
$ns at $opt(stoptime)     "$cbr($srcId) stop"

###################
# Final Procedure #
###################
proc finish {} {
    global ns opt outfile
    global mac propagation cbr_sink mac_sink phy phy_data_sink channel db_manager propagation
    global node_coordinates position
    global ipr_sink ipr ipif udp cbr phy phy_data_sink
    global node_stats tmp_node_stats sink_stats tmp_sink_stats
    global srcId dstId node_ids modemConfig

    puts "---------------------------------------------------------------------"
    puts "Simulation summary"
    puts "number of nodes  : 2"
    puts "packet size      : $opt(pktsize) byte"
    puts "cbr period       : $opt(cbr_period) s"
    puts "simulation length: $opt(txduration) s"
    puts "tx pressure      : [dict get $modemConfig txPressure] dB"
    puts "tx power         : [dict get $modemConfig txPower] W"
    puts "tx frequency     : [dict get $modemConfig freq] Hz"
    puts "tx bandwidth     : [dict get $modemConfig bandwidth] Hz"
    puts "bitrate          : [dict get $modemConfig bitrate] bps"
    if {$opt(ack_mode) == "setNoAckMode"} {
        puts "ACKNOWLEDGEMENT   : disabled"
    } else {
        puts "ACKNOWLEDGEMENT   : active"
    }
    puts "---------------------------------------------------------------------"

    set sum_cbr_throughput     0
    set sum_per                0
    set sum_cbr_sent_pkts      0.0
    set sum_cbr_rcv_pkts       0.0
    set sum_rtx                0.0
    set cbr_throughput         0.0
    set cbr_per                0.0

    foreach node_id $node_ids {
        set position_x              [$position($node_id) getX_]
        set position_y              [$position($node_id) getY_]
        set cbr_throughput              [$cbr($node_id) getthr]
        set cbr_per                     [$cbr($node_id) getper]
        set cbr_sent_pkts               [$cbr($node_id) getsentpkts]
        set cbr_recv_pkts               [$cbr($node_id) getrecvpkts]
        set cbr_txtime              [$cbr($node_id) gettxtime]
        set cbr_resp_rate           [$cbr($node_id) getWithResponseRate]

        puts "position($node_id) X     : $position_x"
        puts "position($node_id) Y     : $position_y"
        puts "cbr($node_id) Throughput     : $cbr_throughput"
        puts "cbr($node_id) Packets sent   : $cbr_sent_pkts"
        puts "cbr($node_id) Packets received: $cbr_recv_pkts"
        puts "cbr($node_id) PER            : $cbr_per       "
        puts "cbr($node_id) Response rate  : $cbr_resp_rate"

        set sum_cbr_sent_pkts [expr $sum_cbr_sent_pkts + $cbr_sent_pkts]
    }

    set ipheadersize        [$ipif($srcId) getipheadersize]
    set udpheadersize       [$udp($srcId) getudpheadersize]
    set cbrheadersize       [$cbr($srcId) getcbrheadersize]
    set sent_pkts           [$cbr($srcId) getsentpkts]
    set throughput          [$cbr($dstId) getthr]
    set recv_pkts           [$cbr($dstId) getrecvpkts]
    set pdr                 [expr $sent_pkts > 0 ? (100.0*$recv_pkts / $sent_pkts) : 100.0]

    puts "Mean Throughput          : $throughput"
    puts "Sent Packets              : $sent_pkts"
    puts "Received Packets          : $recv_pkts"
    puts "Packet Delivery Ratio     : $pdr"
    puts "IP Pkt Header Size        : $ipheadersize"
    puts "UDP Header Size           : $udpheadersize"
    puts "CBR Header Size           : $cbrheadersize"
    if {$opt(ack_mode) == "setAckMode"} {
        puts "MAC-level average retransmissions per node : [expr $sum_rtx/($opt(nn))]"
    }
    puts "---------------------------------------------------------------------"
    puts "- Example of PHY layer statistics for node 1 -"
    puts "Tot. pkts lost            : [$phy(0) getTotPktsLost]"
    puts "Tot. energy               : [$phy(0) getConsumedEnergyTx]"
    puts "Tot. energy with idle     : [computeTotalConsumption $phy(0) [dict get $modemConfig idlePower] $opt(starttime) $opt(stoptime)]"
    puts "Tx energy with idle       : [computeTxConsumption $phy(0) [dict get $modemConfig idlePower] $opt(starttime) $opt(stoptime)]"
    puts "Tot. sensor energy        : [computeSensorConsumption $cbr(0) $opt(frameSize) $modemConfig $opt(starttime) $opt(stoptime)]"

    puts "done!"

    $ns flush-trace
    close $opt(tracefile)
}

$ns at [expr $opt(stoptime) + 250.0]  "finish; $ns halt"

$ns run
