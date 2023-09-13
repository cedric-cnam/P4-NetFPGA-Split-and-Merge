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
#include "my_variables.p4"
#include "SBI_engine.p4"
#include "SnM_metrics.p4"

/*
 * split_and_merge_simple.p4
 * 
 * Description:
 * Split and Merge Module and full Routing Engine based on
 * dst/src IP address and dst/src TCP port
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
        user_metadata.switch_id_match = 0;
        digest_data.unused = 0;
        // Parse Ethernet
        transition select(p.ethernet.etherType) {
            IPV4_TYPE:          parse_ipv4;
            default:            reject;
        } 
    }   

    state parse_ipv4 {
        b.extract(p.ip);
        transition select(p.ip.protocol) {
            TCP_TYPE:   parse_tcp;
            SBI_TYPE:   parse_SB;
            default:    accept;
        }
    }
    
    state parse_SB {
        b.extract(p.SB);
	    transition select(p.SB.type) {
            SBI_ROUTING_TYPE:       parse_SB_sbi_Routing;
            DST_IP_ROUTING_TYPE:    parse_SB_dstIP_Routing;
            SRC_IP_ROUTING_TYPE:    parse_SB_srcIP_Routing;
            SRC_PORT_ROUTING_TYPE:  parse_SB_srcPort_Routing;
            DST_PORT_ROUTING_TYPE:  parse_SB_dstPort_Routing;
            METRIC_TYPE:            parse_SB_metric;
            SNM_PORT_TYPE:          parse_SB_snmPort;
            SET_ID_TYPE:            parse_SB_ID;
            ALIVE_SWITCH_TYPE:      parse_SB_alive;
            default:                reject;
        }
    }

    state parse_SB_alive {
        transition accept;
    }

    state parse_SB_sbi_Routing {
        b.extract(p.SB_sbi_Routing);
        transition accept;
    }

    state parse_SB_dstIP_Routing {
        b.extract(p.SB_dstIP_Routing);
        transition accept;
    }
    
    state parse_SB_srcIP_Routing {
        b.extract(p.SB_srcIP_Routing);
        transition accept;
    }
    
    state parse_SB_srcPort_Routing {
        b.extract(p.SB_srcPort_Routing);
        transition accept;
    }
    
    state parse_SB_dstPort_Routing {
        b.extract(p.SB_dstPort_Routing);
        transition accept;
    }
    
    state parse_SB_metric {
        b.extract(p.SB_metric);
        transition accept;
    }
    
    state parse_SB_snmPort {
        b.extract(p.SB_snmPort);
        transition accept;
    }
    
    state parse_SB_ID {
        b.extract(p.SB_ID);
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
				                R O U T I N G    S T A G E   
        *************************************************************************/
        RoutingStage_inst.apply(p, user_metadata, sume_metadata);
          
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
        b.emit(p.SB_ID);
        b.emit(p.SB_sbi_Routing);
        b.emit(p.SB_dstIP_Routing);
        b.emit(p.SB_srcIP_Routing);
        b.emit(p.SB_srcPort_Routing);
        b.emit(p.SB_dstPort_Routing);
        b.emit(p.SB_snmPort);
        b.emit(p.SB_metric);
    }
}


// Instantiate the switch
SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;

