//
// Copyright (c) 2022 Mario Patetta
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


/*
 * File: @MODULE_NAME@.v 
 * Author: Mario Patetta
 *
 *
 *  Descrioption: TODO
 *
 *
 */



`timescale 1 ps / 1 ps


module @MODULE_NAME@ 
#(
    parameter REG_WIDTH = @REG_WIDTH@,
    parameter OP_WIDTH = 1,
    parameter INPUT_WIDTH = REG_WIDTH+OP_WIDTH+1,
    parameter OUTPUT_WIDTH = REG_WIDTH
)
(
    // Data Path I/O
    input                                           clk_lookup,
    input                                           rst, 
    input                                           tuple_in_@EXTERN_NAME@_input_VALID,
    input   [INPUT_WIDTH-1:0]                       tuple_in_@EXTERN_NAME@_input_DATA,
    output                                          tuple_out_@EXTERN_NAME@_output_VALID,
    output  [OUTPUT_WIDTH-1:0]                      tuple_out_@EXTERN_NAME@_output_DATA
);

    // opCodes
    localparam READ_OP   = 1'd0;
    localparam WRITE_OP  = 1'd1;

    // Convert the input data to readable wires
    wire                           statefulValid_in     = tuple_in_@EXTERN_NAME@_input_DATA[INPUT_WIDTH-1];
    wire    [REG_WIDTH-1:0]        newVal_in            = tuple_in_@EXTERN_NAME@_input_DATA[INPUT_WIDTH-2             -: REG_WIDTH];
    wire    [OP_WIDTH-1:0]         opCode_in            = tuple_in_@EXTERN_NAME@_input_DATA[INPUT_WIDTH-REG_WIDTH-2   -: OP_WIDTH];
    wire                           valid_in             = tuple_in_@EXTERN_NAME@_input_VALID;
    
    // Registers
    reg [REG_WIDTH-1:0]           currentVal_r, currentVal_r_next;
    reg                           valid_r;
    
    
    // Logic
    always @ (*) begin
        // Default values
        currentVal_r_next = currentVal_r;
        
        if (valid_in) begin
            // Eventually overwrite currentVal_r_next
            currentVal_r_next = (opCode_in == WRITE_OP) ? newVal_in : currentVal_r;
        end
    end
    
    // drive the registers
    always @(posedge clk_lookup) begin
        if (rst) begin
            currentVal_r <= {REG_WIDTH{1'b0}};
            valid_r <= 1'b0;
        end else begin
            currentVal_r <= currentVal_r_next;
            valid_r <= valid_in;
        end
    end
   
    /* Assign output signals */
    assign tuple_out_@EXTERN_NAME@_output_VALID = valid_r;
    assign tuple_out_@EXTERN_NAME@_output_DATA  = currentVal_r;


endmodule

