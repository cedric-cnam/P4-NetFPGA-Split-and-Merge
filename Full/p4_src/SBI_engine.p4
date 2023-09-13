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
 * Extern instantiation and control block description
 * for the SBI Routing engine.
 *
 */


#include <core.p4>


/*************************************************************************
							E X T E R N S 
*************************************************************************/
//---------------- Switch ID register -----------------
// Register commands
#define ID_REG_READ  1w0
#define ID_REG_WRITE 1w1

// Register parameters
#define ID_WIDTH   8

@Xilinx_MaxLatency(1)	
@Xilinx_ControlWidth(0)
extern void SwitchID_reg_simple_erw(in  bit<ID_WIDTH>     compVal_in,
                                    in  bit<ID_WIDTH>     newVal_in,
                                    in  bit<1>            opCode_in,
                                    out bit<1>            match_out);

//------------------ SBI cam table -------------------

// CAM Commands
#define LUT_READ		2w0
#define LUT_UPDATE		2w1
#define LUT_RESET		2w2

// Table Parameters
#define SBI_KEY_WIDTH       9       // ID_WIDTH +1 <= We include the ACK in the key since upstream and downstream SBI traffic requires different routing policies
#define PORT_WIDTH          4		// values one-hot-encode physical SUME ports
#define ID_ADDRESS_WIDTH    4

@Xilinx_MaxLatency(64)	
@Xilinx_ControlWidth(0)
extern void sbi_lut_cam(   in  bit<SBI_KEY_WIDTH>		key,
                           in  bit<ID_ADDRESS_WIDTH>	address,
                           in  bit<PORT_WIDTH>		    newPort,
                           in  bit<2>			        opCode,
                           out bit<1>			        match,
                           out bit<PORT_WIDTH>		    result);


//---------------- dst IP tcam table -----------------

// Table Parameters
#define IP_ADDRESS_WIDTH     7

@Xilinx_MaxLatency(64)	
@Xilinx_ControlWidth(0)
extern void dstIP_lut_tcam(in  bit<IP_KEY_WIDTH>		key,
                           in  bit<IP_KEY_WIDTH>		mask,
                           in  bit<IP_ADDRESS_WIDTH>	address,
                           in  bit<PORT_WIDTH>		    newPort,
                           in  bit<2>			        opCode,
                           out bit<1>			        match,
                           out bit<PORT_WIDTH>		    result);
                           
//---------------- src IP tcam table -----------------

@Xilinx_MaxLatency(64)	
@Xilinx_ControlWidth(0)
extern void srcIP_lut_tcam(in  bit<IP_KEY_WIDTH>		key,
                           in  bit<IP_KEY_WIDTH>		mask,
                           in  bit<IP_ADDRESS_WIDTH>	address,
                           in  bit<PORT_WIDTH>		    newPort,
                           in  bit<2>			        opCode,
                           out bit<1>			        match,
                           out bit<PORT_WIDTH>		    result);
                           
//---------------- src port cam table -----------------

// Table Parameters
#define TCP_ADDRESS_WIDTH     4

@Xilinx_MaxLatency(64)	
@Xilinx_ControlWidth(0)
extern void srcPort_lut_cam(in  bit<TCP_KEY_WIDTH>		key,
                            in  bit<TCP_ADDRESS_WIDTH>	address,
                            in  bit<PORT_WIDTH>		    newPort,
                            in  bit<2>			        opCode,
                            out bit<1>			        match,
                            out bit<PORT_WIDTH>		    result);
                           
//---------------- dst port cam table -----------------

@Xilinx_MaxLatency(64)	
@Xilinx_ControlWidth(0)
extern void dstPort_lut_cam(in  bit<TCP_KEY_WIDTH>		key,
                            in  bit<TCP_ADDRESS_WIDTH>	address,
                            in  bit<PORT_WIDTH>		    newPort,
                            in  bit<2>			        opCode,
                            out bit<1>			        match,
                            out bit<PORT_WIDTH>		    result);


/*************************************************************************
							M E T A D A T A 
*************************************************************************/

// user defined metadata: can be used to share information between
// TopParser, TopPipe, and TopDeparser 
struct user_metadata_t {
        bit<TCP_KEY_WIDTH>              target_tcp_port;
        //bit<1>                          snm_ports_match;
        bit<1>                          switch_id_match;
}

// digest data to send to cpu if desired. MUST be 256 bits!
struct digest_data_t {
    bit<256>  unused;
}


/*************************************************************************
							H E A D E R S 
*************************************************************************/

//------------------- STANDARD HEADERS -------------------- 

// standard Ethernet header
header Ethernet_h { 
    bit<48> dstAddr; 
    bit<48> srcAddr; 
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
    bit<32> srcAddr; 
    bit<32> dstAddr;
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



//--------------------- SBI HEADERS ----------------------- 

// Southbound header for the control plane
header Southbound_h {
    bit<ID_WIDTH>       ControllerID;
    bit<ID_WIDTH>       SwitchID;
    bit<8>              type;
    bit<1>              ACK;
    bit<7>	            length;
}

// SBI Routing header for the control plane
header Southbound_sbi_Routing_h {
    bit<SBI_KEY_WIDTH>          key;
    bit<PORT_WIDTH>             port;
    bit<ID_ADDRESS_WIDTH>	    address;
    bit<1>                      check;
    bit<1>                      check_match;
    bit<1>                      reset;
    bit<4>		                unused;
}

// dstIP Routing header for the control plane
header Southbound_dstIP_Routing_h {
    bit<IP_KEY_WIDTH>        key;
    bit<IP_KEY_WIDTH>        mask;
    bit<PORT_WIDTH>          port;
    bit<IP_ADDRESS_WIDTH>	 address;
    bit<2>		             unused;
    bit<1>                   check;
    bit<1>                   check_match;
    bit<1>                   reset;
}

// srcIP Routing header for the control plane
header Southbound_srcIP_Routing_h {
    bit<IP_KEY_WIDTH>        key;
    bit<IP_KEY_WIDTH>        mask;
    bit<PORT_WIDTH>          port;
    bit<IP_ADDRESS_WIDTH>	 address;
    bit<2>		             unused;
    bit<1>                   check;
    bit<1>                   check_match;
    bit<1>                   reset;
}

// srcPort Routing header for the control plane
header Southbound_srcPort_Routing_h {
    bit<TCP_KEY_WIDTH>        key;
    bit<PORT_WIDTH>           port;
    bit<TCP_ADDRESS_WIDTH>	  address;
    bit<1>                    check;
    bit<1>                    check_match;
    bit<1>                    reset;
    bit<5>		              unused;
}

// dstPort Routing header for the control plane
header Southbound_dstPort_Routing_h {
    bit<TCP_KEY_WIDTH>        key;
    bit<PORT_WIDTH>           port;
    bit<TCP_ADDRESS_WIDTH>	  address;
    bit<1>                    check;
    bit<1>                    check_match;
    bit<1>                    reset;
    bit<5>		              unused;
}

// Metric header for the control plane
header Southbound_Metric_h {
    bit<1>                          reset;
    bit<7>                          metricID;
    bit<RESULT_SHORT>               result1;
    bit<RESULT_SHORT>               result2;
    bit<RESULT_SHORT>               result3;
    bit<RESULT_SHORT>                result4;
}

// setSnmPort header for the control plane
header Southbound_snmPort_h {
    bit<TCP_KEY_WIDTH>       key;
}

// setID header for the control plane
header Southbound_SetID_h {
    bit<ID_WIDTH>     NewID;
}

//------------------- LIST OF HEADERS --------------------- 
struct Parsed_packet { 
    Ethernet_h                      ethernet; 
    IPv4_h                          ip;
    TCP_h                           tcp;
    Southbound_h                    SB;
    Southbound_SetID_h              SB_ID;
    Southbound_sbi_Routing_h        SB_sbi_Routing;
    Southbound_dstIP_Routing_h      SB_dstIP_Routing;
    Southbound_srcIP_Routing_h      SB_srcIP_Routing;
    Southbound_srcPort_Routing_h    SB_srcPort_Routing;
    Southbound_dstPort_Routing_h    SB_dstPort_Routing;
    Southbound_snmPort_h            SB_snmPort;
    Southbound_Metric_h             SB_metric;
}


/*************************************************************************
					    R O U T I N G    S T A G E 
*************************************************************************/

control RoutingStage(	inout Parsed_packet p,
                        inout user_metadata_t user_metadata,
                   		inout sume_metadata_t sume_metadata) {

	apply {
	    // Metadata for the routing decision
	    bit<PORT_WIDTH>	         sbi_dst_port = 0;
	    bit<1>                   sbiMatch = 0;
	    bit<PORT_WIDTH>	         dstIP_dst_port = 0;
	    bit<1>                   dstIP_Match = 0;
	    bit<PORT_WIDTH>	         srcIP_dst_port = 0;
	    bit<1>                   srcIP_Match = 0;
	    bit<PORT_WIDTH>	         srcPort_dst_port = 0;
	    bit<1>                   srcPort_Match = 0;
	    bit<PORT_WIDTH>	         dstPort_dst_port = 0;
	    bit<1>                   dstPort_Match = 0;
		    
		//  Manage SBI traffic
	    if ( p.SB.isValid() ) {
	    
	        /*************************************************************************
				      C H E C K / U P D A T E    T H E    S W I T C H    I D   
            *************************************************************************/
	        // Metadata for ID register
	        bit<ID_WIDTH>   newID = 0;
	        bit<1>          ID_opCode = ID_REG_READ;
	        
	        if (p.SB_ID.isValid()) {
	            // Set variables for ID register write
	            newID = p.SB_ID.NewID;
	            ID_opCode = ID_REG_WRITE;
	        }
	        
	        // ID register access
	        SwitchID_reg_simple_erw(p.SB.SwitchID,newID,ID_opCode,user_metadata.switch_id_match);

	        
	        /*************************************************************************
				               S B I    R O U T I N G    T A B L E
            *************************************************************************/
	        
	        if  ( user_metadata.switch_id_match==0   ||                                 // When the switch is not the target of the SBI packet...
	            ( user_metadata.switch_id_match==1 && p.SB_sbi_Routing.isValid() ) ) {  // ... or in case of a SB_sbi_Routing packet
	            // Metadata for the ID LUT
	            bit<SBI_KEY_WIDTH>      sbiKey = p.SB.ACK++p.SB.SwitchID;
	            bit<ID_ADDRESS_WIDTH>   sbiAddress = 0;
	            bit<PORT_WIDTH>         sbiPort = 0;
	            bit<2>                  sbiCode = LUT_READ;

                if (p.SB_sbi_Routing.isValid()) {
                    // Set variables for LUT update
		            sbiKey = p.SB_sbi_Routing.key;
                    if (p.SB_sbi_Routing.reset == 1) {
		                sbiCode     = LUT_RESET;
		            }
		            else if (p.SB_sbi_Routing.check == 0) {
		                sbiAddress	= p.SB_sbi_Routing.address;
		                sbiPort     = p.SB_sbi_Routing.port;
		                sbiCode     = LUT_UPDATE;
		            }
	            }
	            
                // LUT access
                sbi_lut_cam(sbiKey,sbiAddress,sbiPort,sbiCode,sbiMatch,sbi_dst_port);
                
                if (p.SB_sbi_Routing.check == 1) {
	                p.SB_sbi_Routing.port = sbi_dst_port;
	                p.SB_sbi_Routing.check_match = sbiMatch;
	            }
            }
	    }
	    
	    /*************************************************************************
				    D A T A    P L A N E    R O U T I N G    T A B L E S
        *************************************************************************/
	    //--------------------- DST IP LUT ----------------------- 	    
	    // Metadata for the dstIP LUT
	    bit<IP_KEY_WIDTH>        dstIP_Key = p.ip.dstAddr;
	    bit<IP_KEY_WIDTH>        dstIP_Mask = 0;
        bit<IP_ADDRESS_WIDTH>    dstIP_Address = 0;
        bit<PORT_WIDTH>          dstIP_Port = 0;
        bit<2>                   dstIP_Code = LUT_READ;
	    
	    if ( p.SB_dstIP_Routing.isValid() && user_metadata.switch_id_match==1 ) {
            // Set variables for LUT update
		    dstIP_Key = p.SB_dstIP_Routing.key;
		    if (p.SB_dstIP_Routing.reset == 1) {
		        dstIP_Code        = LUT_RESET;
		    }
		    else if (p.SB_dstIP_Routing.check == 0) {
		        dstIP_Mask        = p.SB_dstIP_Routing.mask;
		        dstIP_Address	  = p.SB_dstIP_Routing.address;
		        dstIP_Port        = p.SB_dstIP_Routing.port;
		        dstIP_Code        = LUT_UPDATE;
		    }
	    }
				        
	    // LUT access
	    dstIP_lut_tcam(dstIP_Key, dstIP_Mask, dstIP_Address, dstIP_Port, dstIP_Code, dstIP_Match, dstIP_dst_port);
	        
	    if (p.SB_dstIP_Routing.check == 1) {
	        p.SB_dstIP_Routing.port = dstIP_dst_port;
	        p.SB_dstIP_Routing.check_match = dstIP_Match;
	    }
	    
	    //--------------------- SRC IP LUT -----------------------
	    // Metadata for the srcIP LUT
	    bit<IP_KEY_WIDTH>        srcIP_Key = p.ip.srcAddr;
	    bit<IP_KEY_WIDTH>        srcIP_Mask = 0;
        bit<IP_ADDRESS_WIDTH>    srcIP_Address = 0;
        bit<PORT_WIDTH>          srcIP_Port = 0;
        bit<2>                   srcIP_Code = LUT_READ;
	    
	    if ( p.SB_srcIP_Routing.isValid() && user_metadata.switch_id_match==1 ) {
            // Set variables for LUT update
		    srcIP_Key = p.SB_srcIP_Routing.key;
		    if (p.SB_srcIP_Routing.reset == 1) {
		        srcIP_Code        = LUT_RESET;
		    }
		    else if (p.SB_srcIP_Routing.check == 0) {
		        srcIP_Mask        = p.SB_srcIP_Routing.mask;
		        srcIP_Address	  = p.SB_srcIP_Routing.address;
		        srcIP_Port        = p.SB_srcIP_Routing.port;
		        srcIP_Code        = LUT_UPDATE;
		    }
	    }
				        
	    // LUT access
	    srcIP_lut_tcam(srcIP_Key, srcIP_Mask, srcIP_Address, srcIP_Port, srcIP_Code, srcIP_Match, srcIP_dst_port);
	        
	    if (p.SB_srcIP_Routing.check == 1) {
	        p.SB_srcIP_Routing.port = srcIP_dst_port;
	        p.SB_srcIP_Routing.check_match = srcIP_Match;
	    }
	    
	    //--------------------- SRC PORT LUT -----------------------
	    // Metadata for the srcPort LUT
	    bit<TCP_KEY_WIDTH>        srcPort_Key = p.tcp.srcPort;
        bit<TCP_ADDRESS_WIDTH>    srcPort_Address = 0;
        bit<PORT_WIDTH>           srcPort_Port = 0;
        bit<2>                    srcPort_Code = LUT_READ;
	    
	    if ( p.SB_srcPort_Routing.isValid() && user_metadata.switch_id_match==1 ) {
            // Set variables for LUT update
		    srcPort_Key = p.SB_srcPort_Routing.key;
		    if (p.SB_srcPort_Routing.reset == 1) {
		        srcPort_Code        = LUT_RESET;
		    }
		    else if (p.SB_srcPort_Routing.check == 0) {
		        srcPort_Address	    = p.SB_srcPort_Routing.address;
		        srcPort_Port        = p.SB_srcPort_Routing.port;
		        srcPort_Code        = LUT_UPDATE;
		    }
	    }
				        
	    // LUT access
	    srcPort_lut_cam(srcPort_Key, srcPort_Address, srcPort_Port, srcPort_Code, srcPort_Match, srcPort_dst_port);
	        
	    if (p.SB_srcPort_Routing.check == 1) {
	        p.SB_srcPort_Routing.port = srcPort_dst_port;
	        p.SB_srcPort_Routing.check_match = srcPort_Match;
	    }
	    
	    //--------------------- DST PORT LUT -----------------------
	    // Metadata for the dstPort LUT
	    bit<TCP_KEY_WIDTH>        dstPort_Key = p.tcp.dstPort;
        bit<TCP_ADDRESS_WIDTH>    dstPort_Address = 0;
        bit<PORT_WIDTH>           dstPort_Port = 0;
        bit<2>                    dstPort_Code = LUT_READ;
	    
	    if ( p.SB_dstPort_Routing.isValid() && user_metadata.switch_id_match==1 ) {
            // Set variables for LUT update
		    dstPort_Key = p.SB_dstPort_Routing.key;
		    if (p.SB_dstPort_Routing.reset == 1) {
		        dstPort_Code        = LUT_RESET;
		    }
		    else if (p.SB_dstPort_Routing.check == 0) {
		        dstPort_Address	    = p.SB_dstPort_Routing.address;
		        dstPort_Port        = p.SB_dstPort_Routing.port;
		        dstPort_Code        = LUT_UPDATE;
		    }
	    }
				        
	    // LUT access
	    dstPort_lut_cam(dstPort_Key, dstPort_Address, dstPort_Port, dstPort_Code, dstPort_Match, dstPort_dst_port);
	        
	    if (p.SB_dstPort_Routing.check == 1) {
	        p.SB_dstPort_Routing.port = dstPort_dst_port;
	        p.SB_dstPort_Routing.check_match = dstPort_Match;
	    }
		
		/*************************************************************************
				            R O U T I N G    D E C I S I O N
        *************************************************************************/
	    if ( sbiMatch == 1 ) {
	        sume_metadata.dst_port[0:0] = sbi_dst_port[0:0];
	        sume_metadata.dst_port[2:2] = sbi_dst_port[1:1];
	        sume_metadata.dst_port[4:4] = sbi_dst_port[2:2];
	        sume_metadata.dst_port[6:6] = sbi_dst_port[3:3];    	        
	    }
	    else {
	        if (dstIP_Match == 1) {
	            sume_metadata.dst_port[0:0] = dstIP_dst_port[0:0];
	            sume_metadata.dst_port[2:2] = dstIP_dst_port[1:1];
	            sume_metadata.dst_port[4:4] = dstIP_dst_port[2:2];
	            sume_metadata.dst_port[6:6] = dstIP_dst_port[3:3];
	        }
	        if (srcIP_Match == 1) {
	            sume_metadata.dst_port[0:0] = srcIP_dst_port[0:0];
	            sume_metadata.dst_port[2:2] = srcIP_dst_port[1:1];
	            sume_metadata.dst_port[4:4] = srcIP_dst_port[2:2];
	            sume_metadata.dst_port[6:6] = srcIP_dst_port[3:3];
	        }
	        if (srcPort_Match == 1) {
	            sume_metadata.dst_port[0:0] = srcPort_dst_port[0:0];
	            sume_metadata.dst_port[2:2] = srcPort_dst_port[1:1];
	            sume_metadata.dst_port[4:4] = srcPort_dst_port[2:2];
	            sume_metadata.dst_port[6:6] = srcPort_dst_port[3:3];
	        }
	        if (dstPort_Match == 1) {
	            sume_metadata.dst_port[0:0] = dstPort_dst_port[0:0];
	            sume_metadata.dst_port[2:2] = dstPort_dst_port[1:1];
	            sume_metadata.dst_port[4:4] = dstPort_dst_port[2:2];
	            sume_metadata.dst_port[6:6] = dstPort_dst_port[3:3];
	        }
	    }
	    
	    // Bounce back SBI packet destined to this switch
	    if ( user_metadata.switch_id_match==1 ) {
	        sume_metadata.dst_port = sume_metadata.src_port;
            // Set the ACK
            p.SB.ACK = 1;
        }
	}
}

#endif  /* _SBI_ENGINE_ */
