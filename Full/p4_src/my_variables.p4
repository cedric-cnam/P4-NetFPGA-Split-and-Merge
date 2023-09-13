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


#ifndef _MY_VARIABLES_
#define _MY_VARIABLES_

/*
 * File: my_variables.p4
 * Author: Mario Patetta
 * 
 * Description:
 * Variable declaration for the SBI Engine and the S&M Module
 *
 */


#include <core.p4>

//--------- Ether types ------------- 
#define IPV4_TYPE           0x0800
//-----------------------------------

//--------- IP types ---------------- 
#define TCP_TYPE            6
#define UDP_TYPE            17
#define SBI_TYPE            144
//-----------------------------------

//--------- Header Widths ------------
#define IP_KEY_WIDTH	     32
#define TCP_KEY_WIDTH	     16 

//-------------- SBI ---------------- 
// SB types 
#define SBI_ROUTING_TYPE            0x00
#define DST_IP_ROUTING_TYPE         0x01
#define SRC_IP_ROUTING_TYPE         0x02
#define DST_PORT_ROUTING_TYPE       0x03
#define SRC_PORT_ROUTING_TYPE       0x04
#define METRIC_TYPE                 0x05
#define SNM_PORT_TYPE               0x06
#define SET_ID_TYPE                 0x07
#define ALIVE_SWITCH_TYPE           0x50
// SB Metric IDs 
#define SRC_IP_CARD     0
#define DST_IP_CARD     1
#define SRC_PORTS_CARD  2
#define COUNTERS        3
// SB Metric result sizes  
#define RESULT_SHORT        20
//#define RESULT_LONG         24
// SnM Ports Addressing
#define SnM_PORTS_INDEX_WIDTH      3       
//-----------------------------------

//--------- SUME Ports -------------- 
#define	NF0	0b00000001
#define	NF1	0b00000100
#define	NF2	0b00010000
#define	NF3	0b01000000
//-----------------------------------




#endif  /* _MY_VARIABLES_ */
