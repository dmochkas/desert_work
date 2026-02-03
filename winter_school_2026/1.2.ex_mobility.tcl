# Stack
#             Node 1                         Node 2                         Node 3
#   +--------------------------+   +--------------------------+   +--------------------------+
#   |  7. UW/CBR               |   |  7. UW/CBR               |   |  7. UW/CBR               |
#   +--------------------------+   +--------------------------+   +--------------------------+
#   |  6. UW/UDP               |   |  6. UW/UDP               |   |  6. UW/UDP               |
#   +--------------------------+   +--------------------------+   +--------------------------+
#   |  5. UW/STATICROUTING     |   |  5. UW/STATICROUTING     |   |  5. UW/STATICROUTING     |
#   +--------------------------+   +--------------------------+   +--------------------------+
#   |  4. UW/IP                |   |  4. UW/IP                |   |  4. UW/IP                |
#   +--------------------------+   +--------------------------+   +--------------------------+
#   |  3. UW/MLL               |   |  3. UW/MLL               |   |  3. UW/MLL               |
#   +--------------------------+   +--------------------------+   +--------------------------+
#   |  2. UW/CSMA_ALOHA        |   |  2. UW/CSMA_ALOHA        |   |  2. UW/CSMA_ALOHA        |
#   +--------------------------+   +--------------------------+   +--------------------------+
#   |  1. UW/PHYSICAL          |   |  1. UW/PHYSICAL          |   |  1. UW/PHYSICAL          |
#   +--------------------------+   +--------------------------+   +--------------------------+
#            |         |                    |         |                   |         |       
#   +----------------------------------------------------------------------------------------+
#   |                                     UnderwaterChannel                                  |
#   +----------------------------------------------------------------------------------------+

#####################
# Library Loading   #
#####################
load libMiracle.so
load libMiracleBasicMovement.so
load libmphy.so
load libmmac.so
load libUwmStd.so
load libuwinterference.so
load libuwphy_clmsgs.so
load libuwstats_utilities.so
load libuwphysical.so
load libuwcsmaaloha.so
load libuwip.so
load libuwstaticrouting.so
load libuwmll.so
load libuwudp.so
load libuwcbr.so

#############################
# NS-Miracle initialization #
#############################
# You always need the following two lines to use the NS-Miracle simulator
set ns [new Simulator]
$ns use-Miracle

##################
# Tcl variables  #
##################
set opt(nn)                 2; # Number of Nodes
set opt(starttime)          1
set opt(stoptime)           100001
set opt(txduration)         [expr $opt(stoptime) - $opt(starttime)]

set opt(maxinterval_)       20.0
set opt(freq)               25000.0
set opt(bw)                 5000.0
set opt(bitrate)            4800.0
set opt(ack_mode)           "setNoAckMode"

set opt(txpower)            135.0 
set opt(rngstream)			1
set opt(pktsize)            125
set opt(cbr_period)         60
set opt(auv_speed)          2; #knots

#################
# Random stream #
#################
global defaultRNG
for {set k 0} {$k < $opt(rngstream)} {incr k} {
    $defaultRNG next-substream
}

####################
# Setup tracefiles #
####################
set opt(tracefilename) "./1.2.ex_mobility.tr"
set opt(tracefile) [open $opt(tracefilename) w]
set opt(cltracefilename) "./1.2.ex_mobility.cltr"
set opt(cltracefile) [open $opt(tracefilename) w]

###########################
# Channel and propagation #
###########################
set channel [new Module/UnderwaterChannel]
set propagation [new MPropagation/Underwater]
set data_mask [new MSpectralMask/Rect]
$data_mask setFreq       $opt(freq)
$data_mask setBandwidth  $opt(bw)
$data_mask setPropagationSpeed 1500

#########################
# Module Configuration  #
#########################
#UW/CBR
Module/UW/CBR set packetSize_          $opt(pktsize)
Module/UW/CBR set period_              $opt(cbr_period)
Module/UW/CBR set PoissonTraffic_      1

# UW/PHYsical
Module/UW/PHYSICAL  set BitRate_       $opt(bitrate)
Module/UW/PHYSICAL  set MaxTxSPL_dB_   $opt(txpower)

################################
# Procedure(s) to create nodes #
################################
proc createNode { id } {

    global channel propagation data_mask ns
    global position node udp portnum ipr ipif
    global phy posdb opt rvposx mll mac db_manager
    global node_coordinates cbr

    set node($id) [$ns create-M_Node $opt(tracefile) $opt(cltracefile)]

	#############################################
        #		TODO 			    #
	# insert the layers of the protocol stack.  #
	#############################################

    set cbr($id)  [new Module/UW/CBR]
    set udp($id)  [new Module/UW/UDP]
    set ipr($id)  [new Module/UW/StaticRouting]
    set ipif($id) [new Module/UW/IP]
    set mll($id)  [new Module/UW/MLL]
    set mac($id)  [new Module/UW/CSMA_ALOHA]
    set phy($id)  [new Module/UW/PHYSICAL]


    $node($id) addModule 7 $cbr($id)   0  "CBR"
    $node($id) addModule 6 $udp($id)   0  "UDP"
    $node($id) addModule 5 $ipr($id)   0  "IPR"
    $node($id) addModule 4 $ipif($id)  0  "IPF"   
    $node($id) addModule 3 $mll($id)   0  "MLL"
    $node($id) addModule 2 $mac($id)   0  "MAC"
    $node($id) addModule 1 $phy($id)   0  "PHY"

    $node($id) setConnection $cbr($id)   $udp($id)   0
    $node($id) setConnection $udp($id)   $ipr($id)   0
    $node($id) setConnection $ipr($id)   $ipif($id)  0
    $node($id) setConnection $ipif($id)  $mll($id)   0
    $node($id) setConnection $mll($id)   $mac($id)   0
    $node($id) setConnection $mac($id)   $phy($id)   0
    $node($id) addToChannel  $channel    $phy($id)   0

    set portnum($id) [$udp($id) assignPort $cbr($id) ]
    if {$id > 254} {
        puts "Error: hostnum > 254!!! exiting"
        exit
    }

    $ipif($id) addr [expr ($id) + 1]

    set position($id) [new "Position/BM"]
    $node($id) addPosition $position($id)
    set posdb($id) [new "PlugIn/PositionDB"]
    $node($id) addPlugin $posdb($id) 20 "PDB"
    $posdb($id) addpos [$ipif($id) addr] $position($id)

    set interf_data($id) [new "Module/UW/INTERFERENCE"]
    $interf_data($id) set maxinterval_ $opt(maxinterval_)
    $interf_data($id) set debug_       0

    $phy($id) setPropagation $propagation
    $phy($id) setSpectralMask $data_mask
    $phy($id) setInterference $interf_data($id)
    $mac($id) $opt(ack_mode)
    $mac($id) initialize
}

proc createSink { } {

    global channel propagation smask data_mask ns
    global cbr_sink position_sink node_sink udp_sink portnum_sink interf_data_sink
    global phy_data_sink posdb_sink opt
    global mll_sink mac_sink ipr_sink ipif_sink bpsk interf_sink

    set node_sink [$ns create-M_Node $opt(tracefile) $opt(cltracefile)]

    for {set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
        set cbr_sink($cnt)  [new Module/UW/CBR] 
    }
    set udp_sink       [new Module/UW/UDP]
    set ipr_sink       [new Module/UW/StaticRouting]
    set ipif_sink      [new Module/UW/IP]
    set mll_sink       [new Module/UW/MLL] 
    set mac_sink       [new Module/UW/CSMA_ALOHA]
    set phy_data_sink  [new Module/UW/PHYSICAL]

    for { set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
        $node_sink addModule 7 $cbr_sink($cnt) 0 "CBR"
    }
    $node_sink addModule 6 $udp_sink       0 "UDP"
    $node_sink addModule 5 $ipr_sink       0 "IPR"
    $node_sink addModule 4 $ipif_sink      0 "IPF"   
    $node_sink addModule 3 $mll_sink       0 "MLL"
    $node_sink addModule 2 $mac_sink       0 "MAC"
    $node_sink addModule 1 $phy_data_sink  0 "PHY"

    for { set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
        $node_sink setConnection $cbr_sink($cnt)  $udp_sink      0   
    }
    $node_sink setConnection $udp_sink  $ipr_sink            0
    $node_sink setConnection $ipr_sink  $ipif_sink           0
    $node_sink setConnection $ipif_sink $mll_sink            0 
    $node_sink setConnection $mll_sink  $mac_sink            0
    $node_sink setConnection $mac_sink  $phy_data_sink       0
    $node_sink addToChannel  $channel   $phy_data_sink       0

    for {set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
        set portnum_sink($cnt) [$udp_sink assignPort $cbr_sink($cnt)]
        if {$cnt > 252} {
            puts "Error: hostnum > 252!!! exiting"
            exit
        }
    }

    $ipif_sink addr 254

    set position_sink [new "Position/BM"]
    $node_sink addPosition $position_sink
    set posdb_sink [new "PlugIn/PositionDB"]
    $node_sink addPlugin $posdb_sink 20 "PDB"
    $posdb_sink addpos [$ipif_sink addr] $position_sink

    set interf_data_sink [new "Module/UW/INTERFERENCE"]
    $interf_data_sink set maxinterval_ $opt(maxinterval_)
    $interf_data_sink set debug_       0

    $phy_data_sink setSpectralMask $data_mask
    $phy_data_sink setInterference $interf_data_sink
    $phy_data_sink setPropagation $propagation

    $mac_sink $opt(ack_mode)
    $mac_sink initialize
}

#################
# Node Creation #
#################
# Create here all the nodes you want to network together
for {set id 0} {$id < $opt(nn)} {incr id}  {
    createNode $id
}
createSink

################################
# Inter-node module connection #
################################
proc connectNodes {id1} {
    global ipif ipr portnum cbr cbr_sink ipif_sink portnum_sink ipr_sink

    $cbr($id1) set destAddr_ [$ipif_sink addr]
    $cbr($id1) set destPort_ $portnum_sink($id1)
    $cbr_sink($id1) set destAddr_ [$ipif($id1) addr]
    $cbr_sink($id1) set destPort_ $portnum($id1)
}

# Setup flows
for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
    connectNodes $id1
}

# Fill ARP tables
for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
    for {set id2 0} {$id2 < $opt(nn)} {incr id2}  {
      $mll($id1) addentry [$ipif($id2) addr] [$mac($id2) addr]
    }   
    $mll($id1) addentry [$ipif_sink addr] [ $mac_sink addr]
    $mll_sink addentry [$ipif($id1) addr] [ $mac($id1) addr]
}

# Setup routing table
for {set id1 0} {$id1 < [expr $opt(nn) - 1]} {incr id1}  {
    set id2 [expr $id1 + 1]
    $ipr($id1) addRoute [$ipif_sink addr] [$ipif($id2) addr]
}
set last_id [expr int($opt(nn) - 1)]
$ipr($last_id) addRoute [$ipif_sink addr] [$ipif_sink addr]

# Setup positions
##################################################################
#								TODO							 #
# Set the initial positions of the nodes: sink and normal nodes. #
##################################################################
for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
    $position($id1) setX_ [expr 100 * $id1]
    $position($id1) setY_ [expr 100 * $id1]
    $position($id1) setZ_ -100
}
$position_sink setX_ 0
$position_sink setY_ 0
$position_sink setZ_ 0

proc update_and_check { $t id } {
	global recv_pcks_past recv_pcks ns cbr position cbr_sink

	set recv_pcks [expr [$cbr_sink($id) getrecvpkts] - $recv_pcks_past]
	set recv_pcks_past [$cbr_sink($id) getrecvpkts]

	###############################################################
	#									TODO					  #
	# Here should go the lines that keep re-positioning the node. #
	###############################################################
	set currZ [$position($id) getZ_]
    $position($id) setZ_ [expr $currZ - 50]

	puts "\[[$ns now]\] AUV position ([$position($id) getX_],[$position($id) getY_], [$position($id) getZ_]) - Received $recv_pcks packets, Throughput: [$cbr_sink($id) getthr]"
}

################
# Move one AUV #
################
set recv_pcks_past 0
set recv_pcks 0
set auv_id 1
for {set t 1} {$t < 50} {incr t} {
    $ns at [expr $t*500] "update_and_check $t $auv_id"
	
	# Note: Alternatively to calling a procedure, you can use an expression.
    # $ns at [expr $t*100] {
    #     set recv_pcks [expr [$cbr_sink($auv_id) getrecvpkts] - $recv_pcks_past]
    #     set recv_pcks_past [$cbr_sink($auv_id) getrecvpkts]
	#     # Position update commands #
    #     puts "\[[$ns now]\] AUV position ([$position($auv_id) getX_],[$position($auv_id) getY_], [$position($auv_id) getZ_]) - Received $recv_pcks packets, Throughput: [$cbr_sink($auv_id) getthr]"
    # }
}

#####################
# Start/Stop Timers #
#####################
# Set here the timers to start and/or stop modules (optional)
# e.g., 
for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
    $ns at $opt(starttime)    "$cbr($id1) start"
    $ns at $opt(stoptime)     "$cbr($id1) stop"
}

###################
# Final Procedure #
###################
# Define here the procedure to call at the end of the simulation
proc finish {} {
    global ns opt
    global mac propagation cbr_sink mac_sink phy_data phy_data_sink channel 
    global node_coordinates db_manager propagation position
    global ipr_sink ipr ipif udp cbr phy phy_data_sink position_sink
    global node_stats tmp_node_stats sink_stats tmp_sink_stats

    puts "---------------------------------------------------------------------"
    puts "Simulation summary"
    puts "number of nodes  : $opt(nn)"
    puts "packet size      : $opt(pktsize) byte"
    puts "cbr period       : $opt(cbr_period) s"
    puts "number of nodes  : $opt(nn)"
    puts "simulation length: $opt(txduration) s"
    puts "tx frequency     : $opt(freq) Hz"
    puts "tx bandwidth     : $opt(bw) Hz"
    puts "bitrate          : $opt(bitrate) bps"
    puts "Position sink    : ([$position_sink getX_],[$position_sink getY_], [$position_sink getZ_])"
    puts "Position node 0  : ([$position(0) getX_],[$position(0) getY_], [$position(0) getZ_])"
    puts "Position node 1  : ([$position(1) getX_],[$position(1) getY_], [$position(1) getZ_])"
    puts "---------------------------------------------------------------------"

    set sum_cbr_throughput     0
    set sum_per                0
    set sum_cbr_sent_pkts      0.0
    set sum_cbr_rcv_pkts       0.0    

    for {set i 0} {$i < $opt(nn)} {incr i}  {
        set cbr_throughput           [$cbr_sink($i) getthr]
        set cbr_sent_pkts        [$cbr($i) getsentpkts]
        set cbr_rcv_pkts           [$cbr_sink($i) getrecvpkts]
        
        puts "cbr_sink($i) throughput   : $cbr_throughput"

        set sum_cbr_throughput [expr $sum_cbr_throughput + $cbr_throughput]
        set sum_cbr_sent_pkts  [expr $sum_cbr_sent_pkts + $cbr_sent_pkts]
        set sum_cbr_rcv_pkts   [expr $sum_cbr_rcv_pkts + $cbr_rcv_pkts]
    }
        
    set ipheadersize        [$ipif(1) getipheadersize]
    set udpheadersize       [$udp(1) getudpheadersize]
    set cbrheadersize       [$cbr(1) getcbrheadersize]
    
    puts "Mean Throughput          : [expr ($sum_cbr_throughput/($opt(nn)))]"
    puts "Sent Packets             : $sum_cbr_sent_pkts"
    puts "Received Packets         : $sum_cbr_rcv_pkts"
    puts "Packet Delivery Ratio    : [expr 1.0*$sum_cbr_rcv_pkts/$sum_cbr_sent_pkts * 100]"
    puts "IP Pkt Header Size       : $ipheadersize"
    puts "UDP Header Size          : $udpheadersize"
    puts "CBR Header Size          : $cbrheadersize"
  
    $ns flush-trace
    close $opt(tracefile)
}

###################
# start simulation
###################
$ns at [expr $opt(stoptime) + 250.0]  "finish; $ns halt" 
$ns run

