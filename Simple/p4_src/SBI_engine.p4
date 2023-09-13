//
// Copyright (c) 2022 Mario Patetta, Conservatoire National des Arts et Metiers
// All rights reserved.
//
// SBI_engine is free software: you can redistribute it and/or modify it under the terms of
// the GNU Affero General Public License as published by the Free Software Foundation, either 
// version 3 of the License, or any later version.
//
// SBI_engine is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
// without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// See the GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License along with this program.
// If not, see <https://www.gnu.org/licenses/>.
//


#ifndef _SBI_ENGINE_
#define _SBI_ENGINE_

/*
 * File: SBI_engine.p4
 * Author: Mario Patetta
 * 
 * Description:
 * Variables declaration, LUT extern instantiation
 * and control block description for the SBI engine.
 *
 * This version uses TCAM extern instead of the CAM
 */


#include <core.p4>

typedef bit<48> EthAddr_t; 
typedef bit<32> IPv4Addr_t;

//--------- Ether types ------------- 
#define SOUTHBOUND_TYPE     0x1212
#define IPV4_TYPE           0x0800
//-----------------------------------

//--------- IP types ---------------- 
#define TCP_TYPE            6
#define UDP_TYPE            17
//-----------------------------------

//--------- SB types ---------------- 
#define ROUTING_TYPE        0x01
#define METRIC_TYPE         0x02
#define TCP_PORT_TYPE       0x03
//-----------------------------------

//---- SB Metric result sizes ------- 
#define RESULT_SHORT        24
#define RESULT_LONG         40
//-----------------------------------

//--------- Southbound IDs ---------- 
#define CONTROLLER_ID   0x0001
#define SWITCH_ID       0x0001
//-----------------------------------

//--------- SUME Ports -------------- 
#define	NF0	0b00000001
#define	NF1	0b00000100
#define	NF2	0b00010000
#define	NF3	0b01000000
//-----------------------------------


/*************************************************************************
							E X T E R N S 
*************************************************************************/

//---------------- ipv4 tcam table -----------------

// CAM Commands
#define LUT_READ		4w0
#define LUT_UPDATE		4w1

// Table Parameters
#define KEY_WIDTH	    32		// inputs are IPv4 addresses
#define PORT_WIDTH      4		// values one-hot-encode physical SUME ports
#define ADDRESS_WIDTH   8

@CamLutKeyWidth(KEY_WIDTH)
@CamLutAddressWidth(ADDRESS_WIDTH)
@CamLutNewValWidth(PORT_WIDTH)
@Xilinx_MaxLatency(64)	
@Xilinx_ControlWidth(0)
extern void ipv4_lut_tcam(in  bit<KEY_WIDTH>		    key,
                          in  bit<KEY_WIDTH>		    mask,
                          in  bit<ADDRESS_WIDTH>		address,
                          in  bit<PORT_WIDTH>		    newPort,
                          in  bit<4>			        opCode,
                          out bit<1>			        match,
                          out bit<PORT_WIDTH>		    result);

//--------------------------------------------------

/*************************************************************************
							H E A D E R S 
*************************************************************************/

// standard Ethernet header
header Ethernet_h { 
    EthAddr_t dstAddr; 
    EthAddr_t srcAddr; 
    bit<16> etherType;
}

// IPv4 header without options
header IPv4_h {
    bit<4> version;
    bit<4> ihl;
    bit<8> tos; 
    bit<16> totalLen; 
    bit<16> identification; 
    bit<3> flags;
    bit<13> fragOffset; 
    bit<8> ttl;
    bit<8> protocol; 
    bit<16> hdrChecksum; 
    IPv4Addr_t srcAddr; 
    IPv4Addr_t dstAddr;
}

// TCP header without options
header TCP_h {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4> dataOffset;
    bit<4> res;
    bit<8> flags;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}


// Southbound header for the control plane
header Southbound_h {
    bit<16>     ControllerID;
    bit<16>     SwitchID;
    bit<8>      type;
    bit<1>      ACK;
    bit<7>	    length;
}

// Routing header for the control plane
header Southbound_Routing_h {
    bit<KEY_WIDTH>      key;
    bit<KEY_WIDTH>      mask;
    bit<PORT_WIDTH>     port;
    bit<ADDRESS_WIDTH>	LUT_address;
    bit<1>              check;
    bit<3>		        unused;
}

// Metric header for the control plane
header Southbound_Metric_h {
    bit<1>              reset;
    bit<7>              metricID;
    bit<RESULT_SHORT>   result1;
    bit<RESULT_SHORT>   result2;
    bit<RESULT_SHORT>   result3;
    bit<RESULT_LONG>    result4;
}

// L3Port header for the control plane
header Southbound_TCPPort_h {
    bit<16>             port;
}


// List of all recognized headers
struct Parsed_packet { 
    Ethernet_h              ethernet; 
    IPv4_h                  ip;
    TCP_h                   tcp;
    Southbound_h            SB;
    Southbound_Routing_h    SB_routing;
    Southbound_Metric_h     SB_metric;
    Southbound_TCPPort_h    SB_tcpPort;
}


/*************************************************************************
					    R O U T I N G    S T A G E 
*************************************************************************/

control RoutingStage(	inout Parsed_packet p,
                   		inout sume_metadata_t sume_metadata) {

	apply {
	    // Metadata for LUT access
	    bit<KEY_WIDTH>      key = 0;
	    bit<KEY_WIDTH>      mask = 0;
        bit<ADDRESS_WIDTH>  address = 0;
        bit<PORT_WIDTH>     port = 0;
        bit<4>              LUT_opCode = LUT_READ;
	    bit<1>              match = 0;
	    bit<PORT_WIDTH>	    dst_port = 0;
		    
		    			        
	    if (p.ip.isValid()) {		
	        key = p.ip.dstAddr;
	    }
	    else if ( p.SB.isValid() ) {		        
	        // Bounce the packet to the controller and set the ACK
	        sume_metadata.dst_port = sume_metadata.src_port;
	        EthAddr_t temp = p.ethernet.dstAddr;
            p.ethernet.dstAddr = p.ethernet.srcAddr;
            p.ethernet.srcAddr = temp;
            p.SB.ACK = 1;
                            
            if (p.SB_routing.isValid()) {
                // Set variables for LUT access
		        key = p.SB_routing.key;
		        if (p.SB_routing.check == 0) {
		            mask        = p.SB_routing.mask;
		            address	    = p.SB_routing.LUT_address;
		            port        = p.SB_routing.port;
		            LUT_opCode  = LUT_UPDATE;
		        }
	        }
	    }
				        
	    if (p.ip.isValid() || p.SB_routing.isValid()) {
	        // LUT access
	        ipv4_lut_tcam(key, mask, address, port, LUT_opCode, match, dst_port);
	        
	        if (p.SB_routing.check == 1) {
	            p.SB_routing.port = dst_port;
	        }
	    }
		      
		// traffic routing  
	    if (p.ip.isValid() && match==1) {
	        	        
	        if (dst_port == 1) {
	            sume_metadata.dst_port = NF0;
	        }
	        else if (dst_port == 2) {
	            sume_metadata.dst_port = NF1;
	        }
	        else if (dst_port == 4) {
	            sume_metadata.dst_port = NF2;
	        }
	        else if (dst_port == 8) {
	            sume_metadata.dst_port = NF3;
	        }     	        
	    }    	
	}
}


#endif  /* _SBI_ENGINE_ */
