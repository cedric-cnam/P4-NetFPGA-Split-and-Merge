//
// Copyright (c) 2022 Mario Patetta, Conservatoire National des Arts et Metiers
// Copyright (c) 2017 Stephen Ibanez
// All rights reserved.
//
// This software was developed by Stanford University and the University of Cambridge Computer Laboratory 
// under National Science Foundation under Grant No. CNS-0855268,
// the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
// by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
// as part of the DARPA MRC research programme.
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
// license agreements.  See the NOTICE file distributed with this work for
// additional information regarding copyright ownership.  NetFPGA licenses this
// file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
// "License"); you may not use this file except in compliance with the
// License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@
//


#include <core.p4>
#include <sume_switch.p4>
#include "SBI_engine.p4"
#include "SnM_metrics.p4"

/*
 * standalone_hyperloglog.p4
 * 
 * Description:
 * Split and Merge Module and simple Routing Engine based on
 * dst IP address
 *
 */
  


/*************************************************************************
							P A R S E R 
*************************************************************************/

@Xilinx_MaxPacketRegion(8192)
parser TopParser(packet_in b, 
                 out Parsed_packet p, 
                 out user_metadata_t user_metadata,
                 out digest_data_t digest_data,
                 inout sume_metadata_t sume_metadata) {
    state start {
        b.extract(p.ethernet);
        // Initialise metadata
        user_metadata.target_tcp_port = 0;
        digest_data.unused = 0;
        // Parse Ethernet
        transition select(p.ethernet.etherType) {
            SOUTHBOUND_TYPE:    parse_SB;
            IPV4_TYPE:          parse_ipv4;
            default:            reject;
        } 
    }   
    
    state parse_SB {
        b.extract(p.SB);
	    transition select(p.SB.type) {
            ROUTING_TYPE:   parse_SB_routing;
            METRIC_TYPE:    parse_SB_metric;
            TCP_PORT_TYPE:  parse_SB_tcpPort;
            default:        reject;
        }
    }

    state parse_ipv4 {
        b.extract(p.ip);
        transition select(p.ip.protocol) {
            TCP_TYPE:   parse_tcp;
            default:    accept;
        }
    }

    state parse_SB_routing {
        b.extract(p.SB_routing);
        transition accept;
    }
    
    state parse_SB_metric {
        b.extract(p.SB_metric);
        transition accept;
    }
    
    state parse_SB_tcpPort {
        b.extract(p.SB_tcpPort);
        transition accept;
    }
    
    state parse_tcp {
        b.extract(p.tcp);
        transition accept;
    }
    
}


/*************************************************************************
				M A T C H - A C T I O N    P I P E L I N E  
*************************************************************************/

control TopPipe(inout Parsed_packet p,
                inout user_metadata_t user_metadata, 
                inout digest_data_t digest_data, 
                inout sume_metadata_t sume_metadata) {

    action no_action(port_t x) {
        sume_metadata.dst_port = x;
    }

    table unused_table {
        key = { p.ethernet.dstAddr: exact; }

        actions = {
            no_action;
            NoAction;
        }
        size = 64;
        default_action = NoAction;
    }
    
    RoutingStage()          RoutingStage_inst;
    DstPort_Stage()         DstPort_Stage_inst;
    SrcIP_HLL_Stage()       SrcIP_HLL_Stage_inst;
    DstIP_HLL_Stage()       DstIP_HLL_Stage_inst;
    SrcPort_HLL_Stage()     SrcPort_HLL_Stage_inst;
    Counters_Stage()        Counters_Stage_inst;

    apply {
        unused_table.apply();
          
        /*************************************************************************
				          S P L I T  &  M E R G E      S T A G E   
        *************************************************************************/

        // Parallel Out Register to get tcp dst port to analyze
        DstPort_Stage_inst.apply(p, user_metadata, sume_metadata);

        // Run HLL for Src and Dst IP address and for Src Port
        SrcIP_HLL_Stage_inst.apply(p, user_metadata, sume_metadata);
        DstIP_HLL_Stage_inst.apply(p, user_metadata, sume_metadata);
        SrcPort_HLL_Stage_inst.apply(p, user_metadata, sume_metadata);
        
        // Use Welford Online algorithm to estimate mean and std deviation of pkt sizes.
        // In addition, count the number of SYN packets
        Counters_Stage_inst.apply(p, user_metadata, sume_metadata);
        
        
        /*************************************************************************
				                R O U T I N G    S T A G E   
        *************************************************************************/
        RoutingStage_inst.apply(p, sume_metadata);

    }
}

// Deparser Implementation
@Xilinx_MaxPacketRegion(8192)
control TopDeparser(packet_out b,
                    in Parsed_packet p,
                    in user_metadata_t user_metadata,
                    inout digest_data_t digest_data, 
                    inout sume_metadata_t sume_metadata) { 
    apply {
        b.emit(p.ethernet);         
        b.emit(p.ip);
        b.emit(p.tcp);
        b.emit(p.SB);
        b.emit(p.SB_metric);
        b.emit(p.SB_routing);
        b.emit(p.SB_tcpPort);
    }
}


// Instantiate the switch
SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;

