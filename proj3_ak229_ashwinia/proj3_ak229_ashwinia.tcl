#References: 
#1. 
#2. 
#3. 


set val(pi) 3.1415926535897931
set val(node_count)     101 
set val(duration)       100
set val(packetsize)     16
set val(repeatTx)       1
set val(interval)       0.02
set val(dimx)           50
set val(dimy)           50
set val(nam_file)       mac_grp11_nam.nam
set val(trace_file)     mac_grp11_trace.log
set val(stats_file)     mac_grp11_stats.stats
set val(node_size)      5

set val(chan)           Channel/WirelessChannel    ;# channel type
set val(prop)           Propagation/TwoRayGround   ;# radio-propagation model
set val(netif)          Phy/WirelessPhy            ;# network interface type
set val(mac)            Mac/MAC_GRP11              ;# My Custom MAC
set val(ifq)            Queue/DropTail/PriQueue    ;# interface queue type
set val(ll)             LL                         ;# link layer type
set val(ant)            Antenna/OmniAntenna        ;# antenna model
set val(ifqlen)         50                         ;# max packet in ifq
set val(nn)             $val(node_count)           ;# number of nodes
set val(rp)             DumbAgent                  ;# routing protocol
set val(fullduplex_mode)	false				   ;# since, our source nodes do not RX and sink does not TX

set ns                      [new Simulator]
set tracefd                 [open $val(trace_file) w]
set nam                     [open $val(nam_file) w]
set stats                   [open $val(stats_file) w]
$ns namtrace-all-wireless   $nam $val(dimx) $val(dimy)
$ns trace-all               $tracefd
set topo                    [new Topography]
$topo load_flatgrid         $val(dimx) $val(dimy)

#
# Create God
#
create-god $val(nn)

Mac/MAC_GRP11 set rval_ $val(repeatTx)
Mac/MAC_GRP11 set duration_ $val(interval)
Mac/MAC_GRP11 set fullduplex_mode_ $val(fullduplex_mode)

$ns node-config \
        -adhocRouting $val(rp) \
        -llType $val(ll) \
        -macType $val(mac) \
        -ifqType $val(ifq) \
        -ifqLen $val(ifqlen) \
        -antType $val(ant) \
        -propType $val(prop) \
        -phyType $val(netif) \
        -channelType $val(chan) \
        -topoInstance $topo \
        -agentTrace OFF \
        -routerTrace OFF \
        -macTrace ON \
        -movementTrace OFF 
#
# The only sink node
#
set sink_node [$ns node]
$sink_node random-motion 0
$sink_node set X_ [expr $val(dimx)/2]
$sink_node set Y_ [expr $val(dimy)/2]
$sink_node set Z_ 0
$ns initial_node_pos $sink_node $val(node_size)

set sink [new Agent/LossMonitor]
$ns attach-agent $sink_node $sink

#
# Set up source nodes in a circle around sink.
#
set rng [new RNG]
$rng seed 0

set trand [new RandomVariable/Uniform]
$trand use-rng $rng
$trand set min_ 0
$trand set max_ $val(interval)

#
# Create all the source nodes
#
# each node is at x = 25 cos i*$val(pi/50), y = 25 sin i*$val(pi/50)
for {set i 0} {$i < $val(nn)-1 } {incr i} {
    set src_node($i) [$ns node] 
    $src_node($i) random-motion 0
    set angle [expr $i*$val(pi)/50]
    set angulardist_x [expr cos($angle)]
    set angulardist_y [expr sin($angle)]
    set x [expr $angulardist_x * $val(dimx)/5]
    set y [expr $angulardist_y * $val(dimy)/5]
    $src_node($i) set X_ $x
    $src_node($i) set Y_ $y
    $src_node($i) set Z_ 0
    $ns initial_node_pos $src_node($i) $val(node_size)

    # Inspired by Jing Gao's blog as mentioned in piazza post @56
    set udp($i) [new Agent/UDP]
    $udp($i) set class_ $i
    $ns attach-agent $src_node($i) $udp($i)
    $ns connect $udp($i) $sink

    set cbr($i) [new Application/Traffic/CBR]
    $cbr($i) set packet_size_ $val(packetsize)
    $cbr($i) set interval_ $val(interval)
    $cbr($i) attach-agent $udp($i)
    set start [$trand value]
    $ns at $start "$cbr($i) start"
 
    $ns at $val(duration) "$cbr($i) stop"
}


for {set i 0} {$i < $val(nn)-1 } {incr i} {
    $ns at $val(duration) "$src_node($i) reset";
}
$ns at $val(duration) "stop"
$ns at [expr $val(duration)+$val(interval)] "puts \"NS EXITING...\" ; $ns halt"


proc stop {} {
    global ns tracefd nam stats val sink

    set bytes [$sink set bytes_]
    set losts  [$sink set nlost_]
    set pkts [$sink set npkts_]
    puts $stats "$bytes $losts $pkts"

    $ns flush-trace
    close $nam
    close $tracefd
    close $stats
}

puts "Starting Simulation..."
$ns run
