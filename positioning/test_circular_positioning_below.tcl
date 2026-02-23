######################################
# Flags to enable or disable options #
######################################
set opt(verbose) 			1
set opt(trace_files)		1
set opt(bash_parameters) 	1
set opt(ACK_Active)         0

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
# load libuwreplicator.so
load libuwudp.so
load libuwcbr.so
#load libuwaloha.so
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

source "../common/positioning.tcl"

##################
# Tcl variables  #
##################
set opt(nn)                 4  ;# Number of Nodes
set opt(sink_mode)          3  ;# 1 or 3 sinks are possible
set opt(pktsize)            20 ;# Pkt sike in byte, excluding ip and udp header
set opt(replica_mode)       3  ;# 1 or 3 replicas are possible
set opt(replica_spacing)    0.5
set opt(starttime)          1
set opt(stoptime)           86400 ;# One day # 10000
set opt(txduration)         [expr $opt(stoptime) - $opt(starttime)] ;# Duration of the simulation

set opt(txpower)            156.0  ;#Power transmitted in dB re uPa
#set opt(txpower)            174.0  ;#Power transmitted in dB re uPa
set opt(max_range)          300    ;# Max transmission range

set opt(maxinterval_)       200.0
set opt(freq)               50000.0 ;#Frequency used in Hz
set opt(bw)                 25000.0 ;#Bandwidth used in Hz
set opt(bitrate)            260     ;#Bitrate in bps
set opt(cbr_period)         100
set opt(rngstream)	10

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
} else {
    set opt(finish_mode)        "diag" ;# diag or export
}

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

MPropagation/Underwater set practicalSpreading_ 1.8
MPropagation/Underwater set debug_              0
MPropagation/Underwater set windspeed_          1

#Mpropagation/Underwater set windspeed_ 20
#Mpropagation/Underwater set shipping_ 1


set channel [new Module/UnderwaterChannel]
set propagation [new MPropagation/Underwater]
set data_mask [new MSpectralMask/Rect]
$data_mask setFreq       $opt(freq)
$data_mask setBandwidth  $opt(bw)

#########################
# Module Configuration  #
#########################
Module/UW/CBR set packetSize_          $opt(pktsize)
Module/UW/CBR set period_              $opt(cbr_period)
Module/UW/CBR set PoissonTraffic_      1
Module/UW/CBR set debug_               0

if {$opt(replica_mode) != 1 && $opt(replica_mode) != 3} {
    error "Invalid replica mode $opt(replica_mode)"
}
#Module/UW/REPL set replicas_     $opt(replica_mode)
#Module/UW/REPL set spacing_      $opt(replica_spacing)

#Module/UW/AHOI/PHY  set BitRate_                    $opt(bitrate)
#Module/UW/AHOI/PHY  set AcquisitionThreshold_dB_    5.0
#Module/UW/AHOI/PHY  set RxSnrPenalty_dB_            0
#Module/UW/AHOI/PHY  set TxSPLMargin_dB_             0
#Module/UW/AHOI/PHY  set MaxTxSPL_dB_                $opt(txpower)
#Module/UW/AHOI/PHY  set MinTxSPL_dB_                10
#Module/UW/AHOI/PHY  set MaxTxRange_                 300
#Module/UW/AHOI/PHY  set PER_target_                 0
#Module/UW/AHOI/PHY  set CentralFreqOptimization_    0
#Module/UW/AHOI/PHY  set BandwidthOptimization_      0
#Module/UW/AHOI/PHY  set SPLOptimization_            0
#Module/UW/AHOI/PHY  set debug_                      0

Module/UW/PHYSICAL  set BitRate_                    $opt(bitrate)
Module/UW/PHYSICAL  set AcquisitionThreshold_dB_    15.0
Module/UW/PHYSICAL  set RxSnrPenalty_dB_            0
Module/UW/PHYSICAL  set TxSPLMargin_dB_             0
Module/UW/PHYSICAL  set MaxTxSPL_dB_                $opt(txpower)
Module/UW/PHYSICAL  set MinTxSPL_dB_                10
Module/UW/PHYSICAL  set MaxTxRange_                 1500
Module/UW/PHYSICAL  set PER_target_                 0
Module/UW/PHYSICAL  set CentralFreqOptimization_    0
Module/UW/PHYSICAL  set BandwidthOptimization_      0
Module/UW/PHYSICAL  set SPLOptimization_            0
Module/UW/PHYSICAL  set debug_                      0

#Module/MPhy/BPSK  set TxPower_               $opt(txpower)

################################
# Procedure(s) to create nodes #
################################
proc createNode { id sink_flag } {

    global channel propagation data_mask ns cbr cbr_sink position node udp portnum portnum_sink ipr ipif channel_estimator
    global phy posdb opt rvposx rvposy rvposz mhrouting mll mac woss_utilities woss_creator db_manager
    global node_coordinates interf_data
    global childrenIds nChildren

    if {$id > 254} {
		puts "Max id value is 254"
		exit
    }

    set node($id) [$ns create-M_Node $opt(tracefile) $opt(cltracefile)]

    if {$sink_flag} {
        foreach node_id $childrenIds {
            set cbr_sink($id,$node_id)  [new Module/UW/CBR]
        }
    } else {
        set cbr($id)  [new Module/UW/CBR]
    }

    set udp($id)  [new Module/UW/UDP]
    set ipr($id)  [new Module/UW/StaticRouting]
    set ipif($id) [new Module/UW/IP]
    set mll($id)  [new Module/UW/MLL]
    # set rep($id)  [new Module/UW/REPL]
    set mac($id)  [new Module/UW/CSMA_ALOHA]
    #set phy($id)  [new Module/UW/AHOI/PHY]
    set phy($id) [new Module/UW/PHYSICAL]

    #$ipr($id) setLog 3 "log_ip.out"
    $udp($id) setLog 3 "log_udp.out"
    #$cbr($id) setLog 3 "log_cbr.out"

    if {$sink_flag} {
        foreach node_id $childrenIds {
            $node($id) addModule 7 $cbr_sink($id,$node_id) 0 "CBR"
        }
    } else {
	    $node($id) addModule 7 $cbr($id)   1  "CBR"
    }

    $node($id) addModule 6 $udp($id)   1  "UDP"
    $node($id) addModule 5 $ipr($id)   1  "IPR"
    $node($id) addModule 4 $ipif($id)  1  "IPF"
    $node($id) addModule 3 $mll($id)   1  "MLL"
    # $node($id) addModule 3 $rep($id)   1  "REP"
    $node($id) addModule 2 $mac($id)   1  "MAC"
    $node($id) addModule 1 $phy($id)   0  "PHY"

	# We do only broadcast
	if {$sink_flag} {
        foreach node_id $childrenIds {
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
    # $node($id) setConnection $rep($id)      $mac($id)   1
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
    $phy($id) setInterferenceModel "MEANPOWER"; # "CHUNK" is not supported
    #$phy($id) setRangePDRFileName "../.desert/ahoi/pdr.csv"
    #$phy($id) setSIRFileName "../.desert/ahoi/sir.csv"
    #$phy($id) initLUT

    $mac($id) $opt(ack_mode)
    $mac($id) initialize
}

#####################
# Node Configuration #
#####################
set sinkId 253

set nChildren 32
set childrenIds [list]
for {set i 1} {$i <= $nChildren} {incr i} {
    createNode $i false
    #$position($i) setX_ [expr 10 * ($i + 1 )]
    #$position($i) setY_ [expr 10 * ($i + 1 )]
    #$position($i) setZ_ -1000
    lappend childrenIds $i
}

createNode $sinkId true
$position($sinkId) setX_ 0
$position($sinkId) setY_ 0
$position($sinkId) setZ_ -1000

placeUniformlyAtLBelowParent $childrenIds $sinkId position 1000 500

set sinkIP [$ipif($sinkId) addr]

# set appPort [$udp($sinkId) assignPort $cbr($sinkId)]

foreach child $childrenIds {
    set sinkPort $portnum_sink($sinkId,$child)

    $mll($child) addentry $sinkIP [$mac($sinkId) addr]
    $mll($sinkId) addentry [$ipif($child) addr] [$mac($child) addr]
    $ipr($child) addRoute $sinkIP $sinkIP
    #$ipr($child) addRoute 255 255
    $cbr($child) set destAddr_ $sinkIP
    $cbr($child) set destPort_ $sinkPort

    $ns at $opt(starttime)    "$cbr($child) start"
    $ns at $opt(stoptime)     "$cbr($child) stop"
}


#####################
# Start/Stop Timers #
#####################
#$ns at $opt(starttime)    "$cbr($srcId) start"
#$ns at $opt(stoptime)     "$cbr($srcId) stop"

###################
# Final Procedure #
###################
proc finish {} {
    global ns opt outfile
    global mac propagation cbr_sink mac_sink phy phy_data_sink channel db_manager propagation
    global node_coordinates position
    global ipr_sink ipr ipif udp cbr phy phy_data_sink
    global node_stats tmp_node_stats sink_stats tmp_sink_stats
    global sinkId childrenIds

    if ($opt(verbose)) {
        puts "---------------------------------------------------------------------"
        puts "Simulation summary"
        puts "number of nodes  : $opt(nn)"
        puts "packet size      : $opt(pktsize) byte"
        puts "cbr period       : $opt(cbr_period) s"
        puts "simulation length: $opt(txduration) s"
        puts "tx power         : $opt(txpower) dB"
        puts "tx frequency     : $opt(freq) Hz"
        puts "tx bandwidth     : $opt(bw) Hz"
        puts "bitrate          : $opt(bitrate) bps"
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

    foreach node_id $childrenIds {
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
        puts "cbr($node_id) Throughput     : $cbr_throughput"
        puts "cbr($node_id) Packets sent   : $cbr_sent_pkts"
        puts "cbr_sink($sinkId, $node_id) Packets rcv   : $cbr_rcv_pkts"
        puts "cbr($node_id) PER            : $cbr_per       "
        puts ""

        #set cbr_sink_throughput         [$cbr_sink(254,$node_id) getthr]
        #set cbr_sink_per                [$cbr_sink(254,$node_id) getper]
        set sum_cbr_sent_pkts [expr $sum_cbr_sent_pkts + $cbr_sent_pkts]
        set sum_cbr_rcv_pkts  [expr $sum_cbr_rcv_pkts + $cbr_rcv_pkts]

        #foreach sink_id $sink_ids {
        #    set cbr_rcv_pkts                [$cbr_sink($sink_id,$node_id) getrecvpkts]
        #    set cbr_sink_throughput         [$cbr_sink($sink_id,$node_id) getthr]
        #    set cbr_sink_per                [$cbr_sink($sink_id,$node_id) getper]
        #    if ($opt(verbose)) {
        #        puts "cbr_sink($sink_id) Throughput     : $cbr_sink_throughput"
        #        puts "cbr_sink($sink_id) PER            : $cbr_sink_per"
        #        puts "cbr_sink($sink_id) Recv           : $cbr_rcv_pkts"
        #        puts "-------------------------------------------"
        #    }
        #    set sum_cbr_rcv_pkts  [expr $sum_cbr_rcv_pkts + $cbr_rcv_pkts]
        #}
    }

    set ipheadersize        [$ipif(1) getipheadersize]
    set udpheadersize       [$udp(1) getudpheadersize]
    set cbrheadersize       [$cbr(1) getcbrheadersize]
    # set throughput          [$cbr_sink($sinkId) getthr]
    # set recv_pkts           [$cbr_sink($sinkId) getrecvpkts]
    set pdr                 [expr $sum_cbr_sent_pkts > 0 ? ($sum_cbr_rcv_pkts / $sum_cbr_sent_pkts * 100) : 100.0]

    if ($opt(verbose)) {
        #puts "Mean Throughput          : $throughput"
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
        puts "- Example of PHY layer statistics for node 1 -"
        #puts "Tot. pkts lost            : [$phy(1) getTotPktsLost]"
        #puts "Tot. energy               : [$phy(1) getConsumedEnergyTx]"

        puts "done!"
    }

    $ns flush-trace
    close $opt(tracefile)
}

$ns at [expr $opt(stoptime) + 250.0]  "finish; $ns halt"
#$ns at [expr $opt(stoptime) + 250.0]  "$ns halt"

$ns run
