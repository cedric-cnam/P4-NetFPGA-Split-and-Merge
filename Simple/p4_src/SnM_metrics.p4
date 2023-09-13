//
// Copyright (c) 2022 Mario Patetta, Conservatoire National des Arts et Metiers
// All rights reserved.
//
// SnM_metrics is free software: you can redistribute it and/or modify it under the terms of
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


#ifndef _SnM_Metrics_
#define _SnM_Metrics_

/*
 * File: SnM_Metrics.p4
 * Author: Mario Patetta
 * 
 * Description:
 * TODO
 *
 */


#include <core.p4>

//--------- SB Metric IDs ---------------- 
#define SRC_IP_CARD     0
#define DST_IP_CARD     1
#define SRC_PORTS_CARD  2
#define COUNTERS        3
//----------------------------------------

/*************************************************************************
							E X T E R N S 
*************************************************************************/

//---------------- Simple Register function -----------------
// Register commands
#define TCP_PORT_READ  1w0
#define TCP_PORT_WRITE 1w1

// Function Parameters
#define TCP_PORT_WIDTH    16      // TCP destination port width

@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(0)
extern void dst_port_reg_simple_rw( in  bit<TCP_PORT_WIDTH>     newVal_in,
                                    in  bit<1>                  opCode_in,
                                    out bit<TCP_PORT_WIDTH>     val_out);

//---------------- HyperLogLog functions -----------------
 
// OpCodes
#define HLL_OP_READ     2w0
#define HLL_OP_UPDATE   2w1
#define HLL_OP_RESET    2w2
#define HLL_NO_OP       2w3
 
// Function Parameters
#define IP_ADDR_WIDTH           32
#define BUCKET_INDEX_WIDTH      8
#define BUCKET_CONTENT_WIDTH    4


// SRC IP CARDINALITY
@hllBucketContentWidth(BUCKET_CONTENT_WIDTH)
@Xilinx_MaxLatency(36) // 2**BUCKET_INDEX_WIDTH +4
@Xilinx_ControlWidth(0)
extern void src_ip_hyperloglog(   in  bit<IP_ADDR_WIDTH>      data_in, 
                                  in  bit<2>                  opCode,
                                  out bit<RESULT_SHORT>       result,
                                  out bit<BUCKET_INDEX_WIDTH> empty_buckets);


// DST IP CARDINALITY
@hllBucketContentWidth(BUCKET_CONTENT_WIDTH)
@Xilinx_MaxLatency(36) // 2**BUCKET_INDEX_WIDTH +4
@Xilinx_ControlWidth(0)
extern void dst_ip_hyperloglog(   in  bit<IP_ADDR_WIDTH>      data_in, 
                                  in  bit<2>                  opCode,
                                  out bit<RESULT_SHORT>       result,
                                  out bit<BUCKET_INDEX_WIDTH> empty_buckets);
                                    
// SRC PORT CARDINALITY
@hllBucketContentWidth(BUCKET_CONTENT_WIDTH)
@Xilinx_MaxLatency(36) // 2**BUCKET_INDEX_WIDTH +4
@Xilinx_ControlWidth(0)
extern void src_port_hyperloglog( in  bit<TCP_PORT_WIDTH>     data_in, 
                                  in  bit<2>                  opCode,
                                  out bit<RESULT_SHORT>       result,
                                  out bit<BUCKET_INDEX_WIDTH> empty_buckets);
                                
//------------- Welford function + SYN Counter --------------

// OpCodes
#define WELF_OP_READ     2w0
#define WELF_OP_UPDATE   2w1
#define WELF_OP_RESET    2w2

// Function Parameters
#define PKT_SIZE_WIDTH          11
#define SYN_MASK 8w0b0000_0010
#define SYN_POS 1

@Xilinx_MaxLatency(5)
@Xilinx_ControlWidth(0)
extern void pkt_size_welford( in  bit<PKT_SIZE_WIDTH>   newVal,
                              in  bit<2>                opCode,
                              in  bit<1>                syn_trigger,
                              out bit<RESULT_SHORT>     result_syn_count,
                              out bit<RESULT_SHORT>     result_pkt_count,
                              out bit<RESULT_SHORT>     result_mean,
                              out bit<RESULT_LONG>      result_m2);                                

/*************************************************************************
							M E T A D A T A 
*************************************************************************/

// user defined metadata: can be used to share information between
// TopParser, TopPipe, and TopDeparser 
struct user_metadata_t {
        bit<TCP_PORT_WIDTH>      target_tcp_port;
}

// digest data to send to cpu if desired. MUST be 256 bits!
struct digest_data_t {
    bit<256>  unused;
}


/*************************************************************************
			    D S T - P O R T     R E G I S T E R  
*************************************************************************/
control DstPort_Stage (  inout Parsed_packet p,
                         inout user_metadata_t user_metadata,
                   		 inout sume_metadata_t sume_metadata) {
    apply {
        //---------------- Metadata for Parallel Out Register function to get tcp dst ports to analyze -----------------
        bit<TCP_PORT_WIDTH>     port_in = 0;
        bit<1>                  update_in = TCP_PORT_READ;

        // Control Plane Command
        if (p.SB_snmPort.isValid()) {
            port_in = p.SB_snmPort.key;
            update_in = TCP_PORT_WRITE;
        }
        
        //-------------------- Access Parallel Out Register Extern ---------------------
        dst_port_reg_simple_rw(port_in, update_in, user_metadata.target_tcp_port);
    }
}

/*************************************************************************
			  S R C - I P    C A R D I N A L T Y      S T A G E  
*************************************************************************/

control SrcIP_HLL_Stage (  inout Parsed_packet p,
                           inout user_metadata_t user_metadata,
                   		   inout sume_metadata_t sume_metadata) {
    apply {
        //---------------- Metadata for HyperLogLog function -----------------
        bit<IP_ADDR_WIDTH>      data_in = 0;
        bit<2>                  opCode = HLL_NO_OP;
        bit<RESULT_SHORT>       result = 0;
        bit<BUCKET_INDEX_WIDTH> empty_buckets = 0;
        bit<1>                  hll_trigger = 0;

        // Data Plane Traffic
        if ( (p.tcp.isValid()) && (p.tcp.dstPort == user_metadata.target_tcp_port) ) {
            data_in = p.ip.srcAddr;
            opCode = HLL_OP_UPDATE;
            hll_trigger = 1;
        }
        
        // Control Plane Query
        if (p.SB_metric.isValid() && p.SB_metric.metricID == SRC_IP_CARD) {
            hll_trigger = 1;
            opCode = HLL_OP_READ;
            if (p.SB_metric.reset == 1) {
                opCode = HLL_OP_RESET;
            }
        }
        
        //-------------------- Access HyperLogLog Externs ---------------------
	    if ( hll_trigger == 1 )  {
	        src_ip_hyperloglog(data_in, opCode, result, empty_buckets);
        }
            
        // Reply to Control Plane Query
        if (p.SB_metric.isValid() && p.SB_metric.metricID == SRC_IP_CARD) {
            p.SB_metric.result1 = result;
            p.SB_metric.result2[BUCKET_INDEX_WIDTH-1:0] = empty_buckets;
        }
    }
}

/*************************************************************************
			  D S T - I P    C A R D I N A L T Y      S T A G E  
*************************************************************************/

control DstIP_HLL_Stage (  inout Parsed_packet p,
                           inout user_metadata_t user_metadata,
                   		   inout sume_metadata_t sume_metadata) {
    apply {
        //---------------- Metadata for HyperLogLog function -----------------
        bit<IP_ADDR_WIDTH>      data_in = 0;
        bit<2>                  opCode = HLL_NO_OP;
        bit<RESULT_SHORT>       result = 0;
        bit<BUCKET_INDEX_WIDTH> empty_buckets = 0;
        bit<1>                  hll_trigger = 0;

        // Data Plane Traffic
        if ( (p.tcp.isValid()) && (p.tcp.dstPort == user_metadata.target_tcp_port) ) {
            data_in = p.ip.dstAddr;
            opCode = HLL_OP_UPDATE;
            hll_trigger = 1;
        }
        
        // Control Plane Query
        if (p.SB_metric.isValid() && p.SB_metric.metricID == DST_IP_CARD) {
            hll_trigger = 1;
            opCode = HLL_OP_READ;
            if (p.SB_metric.reset == 1) {
                opCode = HLL_OP_RESET;
            }
        }
        
        //-------------------- Access HyperLogLog Externs ---------------------
	    if ( hll_trigger == 1 )  {
	        dst_ip_hyperloglog(data_in, opCode, result, empty_buckets);
        }
            
        // Reply to Control Plane Query
        if (p.SB_metric.isValid() && p.SB_metric.metricID == DST_IP_CARD) {
            p.SB_metric.result1 = result;
            p.SB_metric.result2[BUCKET_INDEX_WIDTH-1:0] = empty_buckets;
        }
    }
}

/*************************************************************************
			S R C - P O R T    C A R D I N A L T Y      S T A G E  
*************************************************************************/

control SrcPort_HLL_Stage ( inout Parsed_packet p,
                            inout user_metadata_t user_metadata,
                   		    inout sume_metadata_t sume_metadata) {
    apply {
        //---------------- Metadata for HyperLogLog function -----------------
        bit<TCP_PORT_WIDTH>     data_in = 0;
        bit<2>                  opCode = HLL_NO_OP;
        bit<RESULT_SHORT>       result = 0;
        bit<BUCKET_INDEX_WIDTH> empty_buckets = 0;
        bit<1>                  hll_trigger = 0;

        // Data Plane Traffic
        if ( (p.tcp.isValid()) && (p.tcp.dstPort == user_metadata.target_tcp_port) ) {
            data_in = p.tcp.srcPort;
            opCode = HLL_OP_UPDATE;
            hll_trigger = 1;
        }
        
        // Control Plane Query
        if (p.SB_metric.isValid() && p.SB_metric.metricID == SRC_PORTS_CARD) {
            hll_trigger = 1;
            opCode = HLL_OP_READ;
            if (p.SB_metric.reset == 1) {
                opCode = HLL_OP_RESET;
            }
        }
        
        //-------------------- Access HyperLogLog Externs ---------------------
	    if ( hll_trigger == 1 )  {
	        src_port_hyperloglog(data_in, opCode, result, empty_buckets);
        }
            
        // Reply to Control Plane Query
        if (p.SB_metric.isValid() && p.SB_metric.metricID == SRC_PORTS_CARD) {
            p.SB_metric.result1 = result;
            p.SB_metric.result2[BUCKET_INDEX_WIDTH-1:0] = empty_buckets;
        }
    }
}

/*************************************************************************
	        P K T   S I Z E   +   S Y N   C O U N T   S T A G E  
*************************************************************************/

control Counters_Stage ( inout Parsed_packet p,
                         inout user_metadata_t user_metadata,
                   		 inout sume_metadata_t sume_metadata) {
    apply {
        //---------------- Metadata for Welford extern -----------------
        bit<16>                  payload_len;
        bit<PKT_SIZE_WIDTH>      newVal = 0;
        bit<2>                   opCode = WELF_OP_READ;
        bit<RESULT_SHORT>        result_syn_count = 0;
        bit<RESULT_SHORT>        result_pkt_count = 0;
        bit<RESULT_SHORT>        result_mean = 0;
        bit<RESULT_LONG>         result_m2 = 0;
        bit<1>                   welf_trigger = 0;
        bit<1>                   syn_trigger = 0;

        // Data Plane Traffic
        if ( (p.tcp.isValid()) && (p.tcp.dstPort == user_metadata.target_tcp_port) ) {
            payload_len = p.ip.totalLen - 40;       // 40 is the length of IP + TCP headers, ip.totalLen does not take into account the Eth header length
            newVal = payload_len[10:0];
            opCode = WELF_OP_UPDATE;
            welf_trigger = 1;
            if ( (p.tcp.flags & SYN_MASK) >> SYN_POS == 1 ) {
                syn_trigger = 1;
            }
        }

        // Control Plane Query
        if (p.SB_metric.isValid() && p.SB_metric.metricID == COUNTERS) {
            welf_trigger = 1;
            opCode = WELF_OP_READ;
            if (p.SB_metric.reset == 1) {
                opCode = WELF_OP_RESET;
            }
        }
        
        //-------------------- Access Welford Externs ---------------------
	    if ( welf_trigger == 1)  {
	        pkt_size_welford(newVal, opCode, syn_trigger, result_syn_count, result_pkt_count, result_mean, result_m2);
        }
            
        // Reply to Control Plane Query
        if (p.SB_metric.isValid() && p.SB_metric.metricID == COUNTERS) {
            p.SB_metric.result1 = result_syn_count;
            p.SB_metric.result2 = result_pkt_count;
            p.SB_metric.result3 = result_mean;
            p.SB_metric.result4 = result_m2;
        }        
    }
}

#endif  /* _SnM_METRICS_ */
