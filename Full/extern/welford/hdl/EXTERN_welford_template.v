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
 *  Welford Algorithm for iterative mean_r and varianceiance estimation.
 *  Added extension for an additional triggerable counter
 *
 *  Descrioption: TODO
 *
 *
 */

`timescale 1 ps / 1 ps

module @MODULE_NAME@
#(

    parameter DATAIN_WIDTH      = @DATAIN_WIDTH@,                   // For packet size 11 bits are enough
    parameter OP_WIDTH          = 2,
    parameter INPUT_WIDTH       = DATAIN_WIDTH + OP_WIDTH +1 /* syn_flag */ +1,
    parameter RES_SHORT_WIDTH   = @RESULT_SHORT_WIDTH@,
    //parameter RES_LONG_WIDTH    = @RESULT_LONG_WIDTH@,
    parameter OUTPUT_WIDTH      = 4*RES_SHORT_WIDTH //+ RES_LONG_WIDTH
   
 )(
     input                                          clk_lookup,
     input                                          rst, 
     input                                          tuple_in_@EXTERN_NAME@_input_VALID,
     input   [INPUT_WIDTH-1:0]                      tuple_in_@EXTERN_NAME@_input_DATA,
     output                                         tuple_out_@EXTERN_NAME@_output_VALID,
     output  [OUTPUT_WIDTH-1:0]                     tuple_out_@EXTERN_NAME@_output_DATA
 );
     
     
     //// Input buffer to hold requests ////
     // Signals 
     wire                               statefulValid_fifo; 
     wire    [DATAIN_WIDTH-1:0]         newVal_fifo;
     wire    [OP_WIDTH-1:0]             opCode_fifo;
     wire                               syn_flag_fifo;    
     wire                               empty_fifo;
     wire                               full_fifo;
     reg                                rd_en_fifo;
     // Instantiation
     fallthrough_small_fifo
     #(
         .WIDTH(INPUT_WIDTH),
         .MAX_DEPTH_BITS(3)
     )
     request_fifo
     (
        // Outputs
        .dout                           ({statefulValid_fifo, newVal_fifo, opCode_fifo, syn_flag_fifo}),
        .full                           (full_fifo),
        .nearly_full                    (),
        .prog_full                      (),
        .empty                          (empty_fifo),
        // Inputs
        .din                            (tuple_in_@EXTERN_NAME@_input_DATA),
        .wr_en                          (tuple_in_@EXTERN_NAME@_input_VALID),
        .rd_en                          (rd_en_fifo),
        .reset                          (rst),
        .clk                            (clk_lookup)
     );
     
     //// Upscale newVal
     localparam      MULT_WORD_SIZE = 18;
     localparam      SCALING = MULT_WORD_SIZE-DATAIN_WIDTH;
     wire   [DATAIN_WIDTH+SCALING-1:0]    scaledVal  = {newVal_fifo, {SCALING{1'b0}}};    // NB: DATAIN_WIDTH+SCALING = MULT_WORD_SIZE
     
     
     //// Metric Distributed RAM
     // Signals
     reg            [RES_SHORT_WIDTH-1:0]                 syn_cnt_ram;
     reg            [RES_SHORT_WIDTH-1:0]                 syn_cnt_din_ram;
     wire           [RES_SHORT_WIDTH-1:0]                 syn_cnt_dout_ram;
     reg                                                  syn_cnt_we_ram;
     reg            [RES_SHORT_WIDTH-1:0]                 pkt_cnt_ram;
     reg            [RES_SHORT_WIDTH-1:0]                 pkt_cnt_din_ram;
     wire           [RES_SHORT_WIDTH-1:0]                 pkt_cnt_dout_ram;
     reg                                                  pkt_cnt_we_ram;
     reg  signed    [DATAIN_WIDTH+SCALING:0]              mean_ram;     
     reg  signed    [DATAIN_WIDTH+SCALING:0]              mean_din_ram;
     wire signed    [DATAIN_WIDTH+SCALING:0]              mean_dout_ram;
     reg                                                  mean_we_ram;
     reg  signed    [2*DATAIN_WIDTH+SCALING:0]            variance_ram;
     reg  signed    [2*DATAIN_WIDTH+SCALING:0]            variance_din_ram;
     wire signed    [2*DATAIN_WIDTH+SCALING:0]            variance_dout_ram;
     reg                                                  variance_we_ram;
     // Initialization
     initial begin
		syn_cnt_ram = 0;
		pkt_cnt_ram = 0;
		mean_ram = 0;
		variance_ram = 0;
     end
     // Description
     always @(posedge clk_lookup) begin
        // Synchronous Update
	    if (syn_cnt_we_ram) begin
		    syn_cnt_ram <= syn_cnt_din_ram;
	    end
	    if (pkt_cnt_we_ram) begin
		    pkt_cnt_ram <= pkt_cnt_din_ram;
	    end
	    if (mean_we_ram) begin
		    mean_ram <= mean_din_ram;
	    end
	    if (variance_we_ram) begin
		    variance_ram <= variance_din_ram;
	    end
     end
     // Asynchronous Read
     assign syn_cnt_dout_ram = syn_cnt_ram;
     assign pkt_cnt_dout_ram = pkt_cnt_ram;
     assign mean_dout_ram    = mean_ram;
     assign variance_dout_ram      = variance_ram;
     
     
     //// Closest Power of 2 module
     //Parameters
     localparam SHIFT_WIDTH = $clog2(RES_SHORT_WIDTH);
     // Signals
     //reg    [RES_SHORT_WIDTH-1:0]   shift_in;
     wire   [SHIFT_WIDTH-1:0]       shift_r_next;
     reg    [SHIFT_WIDTH-1:0]       shift_r;
     // Instantiation
     closest_pover_of_two
     #(
        .INPUT_WIDTH(RES_SHORT_WIDTH)
     ) shift_cpo2 (
        .input_string(pkt_cnt_dout_ram),
        .result(shift_r_next)
     );
     
     
     // Multiplier
     // Signals
     reg  signed    [DATAIN_WIDTH+SCALING:0]        delta1, delta1_next;
     reg  signed    [DATAIN_WIDTH+SCALING:0]        delta2, delta2_next;
     reg  signed    [2*DATAIN_WIDTH+SCALING:0]      delta3;
     reg  signed    [2*MULT_WORD_SIZE:0]            delta_prod_r;
     wire signed    [2*MULT_WORD_SIZE:0]            delta_prod_next;
     
     // Instantiation
     multiplier #(
         .MULT_WORD_SIZE(MULT_WORD_SIZE)
     ) multiplier_inst (
         .in_a(delta1),
         .in_b(delta2),
         .out(delta_prod_next)
     );
    
    
    //// Concatenate module
     // Signals
     reg  [RES_SHORT_WIDTH-1:0]                  syn_cnt_out;
     reg  [RES_SHORT_WIDTH-1:0]                  pkt_cnt_out;
     reg  [DATAIN_WIDTH+SCALING:0]               mean_out;
     reg  [2*DATAIN_WIDTH+SCALING:0]             variance_out;
     wire [OUTPUT_WIDTH-1:0]                     tuple_out;
     // Instantiation
     concatenate
     #(
         .SCALING(SCALING),
         .RES_SHORT_WIDTH(RES_SHORT_WIDTH),
         //.RES_LONG_WIDTH(RES_LONG_WIDTH),
         .OUTPUT_WIDTH(OUTPUT_WIDTH)
     ) concatenate_inst (
         .syn_cnt(syn_cnt_out),
         .pkt_cnt(pkt_cnt_out),
         .mean(mean_out),
         .variance(variance_out),
         .tuple_out(tuple_out)
     );
          
     
     /* State Machine */
     // opCodes
     localparam OP_READ      = 2'd0;
     localparam OP_UPDATE    = 2'd1;
     localparam OP_RESET     = 2'd2;
     // State Machine states
     localparam StIdle       = 2'd0;
     localparam StFindCP2    = 2'd1;
     localparam StUpdateMean = 2'd2;
     localparam StUpdateVar  = 2'd3;
     // State Machine Signals
     reg    [1:0]   state_r,     state_r_next;
     reg            cycle_cnt_r, cycle_cnt_r_next;
     reg            valid_out;
     // Logic                                                  
     always @(*) begin
         // Default FSM Signals
         state_r_next = state_r;
         cycle_cnt_r_next = cycle_cnt_r;
         rd_en_fifo = 0;
         // Default Metric Updates
         syn_cnt_we_ram = 0;
         pkt_cnt_we_ram = 0;
         mean_we_ram = 0;
         variance_we_ram = 0;
         syn_cnt_din_ram = syn_cnt_dout_ram + 1;             
         pkt_cnt_din_ram = pkt_cnt_dout_ram + 1;
         mean_din_ram = 0;
         variance_din_ram = 0;
         delta1_next = delta1;
         delta2_next = delta2;
         delta3 = 0;
         //delta_prod_next = delta_prod;
         // Output Signals
         syn_cnt_out = 0;
         pkt_cnt_out = 0;
         mean_out = 0;
         variance_out = 0;
         valid_out = 0;
         
         // states
         case (state_r)
             StIdle: begin
                 cycle_cnt_r_next = 1'b0;
                 if (~empty_fifo) begin
                     rd_en_fifo = 1;
                     if (statefulValid_fifo) begin
                         if (opCode_fifo == OP_UPDATE) begin
                             // Update pkt and syn counters, compute delta1
                             syn_cnt_we_ram = syn_flag_fifo ? 1 : 0;
                             pkt_cnt_we_ram = 1;
                             delta1_next = scaledVal - mean_dout_ram[DATAIN_WIDTH+SCALING-1:0];
                             state_r_next = StFindCP2;
                         end else if (opCode_fifo == OP_RESET) begin
                             syn_cnt_we_ram = 1;
                             syn_cnt_din_ram = 0;
                             pkt_cnt_we_ram = 1;
                             pkt_cnt_din_ram = 0;
                             mean_we_ram = 1;
                             mean_din_ram = 0;
                             variance_we_ram = 1;
                             variance_din_ram = 0;
                             valid_out = 1;
                         end else if (opCode_fifo == OP_READ) begin
                             syn_cnt_out = syn_cnt_dout_ram;
                             pkt_cnt_out = pkt_cnt_dout_ram;
                             mean_out    = mean_dout_ram;
                             variance_out      = variance_dout_ram;
                             valid_out = 1;
                         end else begin 
                             valid_out = 1;
                         end
                     end else begin
                         valid_out = 1;
                     end
                 end
             end
             
             StFindCP2 : begin
                // Find Closest Power of 2
                //shift_in = pkt_cnt_dout_ram;
                state_r_next = StUpdateMean;
             end
             
             StUpdateMean : begin
                 // Update mean, compute delta2
                 mean_we_ram = 1;
                 mean_din_ram = mean_dout_ram + (delta1 >>> shift_r);
                 delta2_next = scaledVal - mean_din_ram[DATAIN_WIDTH+SCALING-1:0];
                 state_r_next = StUpdateVar;
             end
             
             StUpdateVar : begin
                if (cycle_cnt_r == 1'b0) begin
                    // Wait multiplication
                    cycle_cnt_r_next = cycle_cnt_r + 1;
                end else begin
                    variance_we_ram = 1;
                    delta3 = (delta_prod_r[2*MULT_WORD_SIZE-:2*DATAIN_WIDTH+SCALING+1] - variance_dout_ram);
                    variance_din_ram = variance_dout_ram + ( delta3 >>> shift_r);
                    valid_out = 1;
                    state_r_next = StIdle;
                end
             end
             
         endcase
     end // End state Machine
     
     
     // Register Update
     always @(posedge clk_lookup) begin
         if (rst) begin
             state_r <= StIdle;
         end else begin
             state_r <= state_r_next;
         end
     end
     
     always @(posedge clk_lookup) begin
        cycle_cnt_r <= cycle_cnt_r_next;
        delta1 <= delta1_next;
        delta2 <= delta2_next;
        delta_prod_r <= delta_prod_next;
        shift_r <= shift_r_next;
     end         
     
     
     assign tuple_out_@EXTERN_NAME@_output_DATA  = tuple_out;
     assign tuple_out_@EXTERN_NAME@_output_VALID = valid_out;    
     
 endmodule

