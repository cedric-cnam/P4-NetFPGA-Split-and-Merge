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
 *  Welford Algorithm for iterative mean and variance estimation.
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
    parameter INPUT_WIDTH       = DATAIN_WIDTH + OP_WIDTH +2,
    parameter RES_SHORT_WIDTH   = @RESULT_SHORT_WIDTH@,
    parameter RES_LONG_WIDTH    = @RESULT_LONG_WIDTH@,
    parameter OUTPUT_WIDTH      = 3*RES_SHORT_WIDTH + RES_LONG_WIDTH
 )(
     input                                          clk_lookup,
     input                                          rst, 
     input                                          tuple_in_@EXTERN_NAME@_input_VALID,
     input   [INPUT_WIDTH-1:0]                      tuple_in_@EXTERN_NAME@_input_DATA,
     output                                         tuple_out_@EXTERN_NAME@_output_VALID,
     output  [OUTPUT_WIDTH-1:0]                     tuple_out_@EXTERN_NAME@_output_DATA
 );
     
     // request_fifo signals 
     wire                            statefulValid_fifo; 
     wire    [DATAIN_WIDTH-1:0]      newVal_fifo;
     wire    [OP_WIDTH-1:0]          opCode_fifo;
     wire                            syn_trigger_fifo;    
     wire                            empty_fifo;
     wire                            full_fifo;
     reg                             rd_en_fifo;
     
     //// Input buffer to hold requests ////
     fallthrough_small_fifo
     #(
         .WIDTH(INPUT_WIDTH),
         .MAX_DEPTH_BITS(3)
     )
     request_fifo
     (
        // Outputs
        .dout                           ({statefulValid_fifo, newVal_fifo, opCode_fifo, syn_trigger_fifo}),
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
     
     // Upscale newVal
     localparam      SCALING = RES_SHORT_WIDTH-9;                               // Should be on the order of the maximum traffic we expect
     localparam      MULT_WORD_SMALL_SIZE = 18;                                 //DSP48E1 has 18*24 multiplier
     localparam      DELTA_SCALING = MULT_WORD_SMALL_SIZE - DATAIN_WIDTH -1;    // 1 bit is used for the sign
     wire      [SCALING-1:0]                        bot_padding = 0;
     wire      [DATAIN_WIDTH+SCALING-1:0]           scaledVal  = {newVal_fifo, bot_padding};
     
     // FSM signals
     reg            [RES_SHORT_WIDTH-1:0]                  syn_count,      syn_count_next;
     reg            [RES_SHORT_WIDTH-1:0]                  pkt_count,      pkt_count_next;
     reg  signed    [DATAIN_WIDTH+SCALING:0]               mean,           mean_next;
     reg  signed    [MULT_WORD_SMALL_SIZE-1:0]             delta2;
     reg  signed    [DATAIN_WIDTH+SCALING:0]               delta1,         delta1_next,    delta2_next;
     reg  signed    [RES_LONG_WIDTH+2*DELTA_SCALING:0]     m2,             m2_next;
     reg  signed    [2*MULT_WORD_SMALL_SIZE:0]             m2_increment,   m2_increment_next;
     reg            [1:0]                                  state,          state_next;
     reg                                                   valid_out,      valid_out_next;
     
     
     // bitwise log2 signals
     localparam SHIFT_WIDTH = $clog2(RES_SHORT_WIDTH);
     wire   [SHIFT_WIDTH-1:0]       shift_next;
     reg    [SHIFT_WIDTH-1:0]       shift;
     
     // leading one module
     bitwise_log2
     #(
        .INPUT_WIDTH(RES_SHORT_WIDTH)
     ) bitwise_log2_inst (
        .input_string(pkt_count),
        .result(shift_next)
     );
     
     
     // multiplier module signals
     wire signed   [MULT_WORD_SMALL_SIZE-1:0]  delta1_sampl = delta1[DATAIN_WIDTH+SCALING -: MULT_WORD_SMALL_SIZE]; // Sample delta1 to fit in the multiplier
     wire signed   [2*MULT_WORD_SMALL_SIZE:0]  multiplier_result;
     
     // multiplier module
     multiply
    #(
        .MULT_WORD_SMALL_SIZE(MULT_WORD_SMALL_SIZE)
    ) multiply_inst (
        .x(delta1_sampl),
        .y(delta2),
        .result(multiplier_result)
    );
          
     
     // State Machine States
     localparam STAGE_ONE    = 2'd0;
     localparam STAGE_TWO    = 2'd1;
     localparam STAGE_THREE  = 2'd2;
     localparam STAGE_FOUR   = 2'd3;
     
     // opCodes
     localparam OP_READ      = 2'd0;
     localparam OP_UPDATE    = 2'd1;
     localparam OP_RESET     = 2'd2;
     
     // State Machine
     always @(*) begin
         // Default FSM Signals
         state_next = state;
         rd_en_fifo = 0;
         valid_out_next = 0;
         // Default Metric Updates
         syn_count_next = syn_count;             
         pkt_count_next = pkt_count;
         mean_next = mean;
         m2_next = m2 + m2_increment;
         m2_increment_next = 0;
         delta1_next = delta1;
         delta2_next[DATAIN_WIDTH+SCALING-MULT_WORD_SMALL_SIZE:0] = 0;
         delta2_next[DATAIN_WIDTH+SCALING-:MULT_WORD_SMALL_SIZE]= delta2;
         
         // States
         case (state)
             STAGE_ONE: begin
                 if (~empty_fifo) begin
                     rd_en_fifo = 1;
                     if (statefulValid_fifo) begin
                         if (opCode_fifo == OP_UPDATE) begin
                             syn_count_next = syn_trigger_fifo ? (syn_count+1) : syn_count;
                             pkt_count_next = pkt_count +1;
                             delta1_next = scaledVal - mean[DATAIN_WIDTH+SCALING-1:0];
                             state_next = STAGE_TWO;
                         end else if (opCode_fifo == OP_RESET) begin
                             syn_count_next = 0;
                             pkt_count_next = 0;
                             mean_next = 0;
                             m2_next = 0;
                             valid_out_next = 1;
                         end else begin  // Including the case opCode_fifo == OP_READ
                             valid_out_next = 1;
                         end
                     end else begin
                         valid_out_next = 1;
                     end
                 end
             end
             
             STAGE_TWO : begin
                // Wait leading one module
                state_next = STAGE_THREE;
             end
             
             STAGE_THREE : begin
                 mean_next = mean + (delta1 >>> shift);
                 delta2_next = scaledVal - mean_next[DATAIN_WIDTH+SCALING-1:0];
                 state_next = STAGE_FOUR;
             end
             
             STAGE_FOUR : begin
                m2_increment_next = multiplier_result;
                valid_out_next = 1;
                state_next = STAGE_ONE;
             end
             
         endcase
     end // End State Machine
     
     // Register Update
     always @(posedge clk_lookup) begin
         if (rst) begin
             state <= STAGE_ONE;
             valid_out <= 0;
             syn_count <= 0;
             pkt_count <= 0;
             mean <= 0;
             m2 <= 0;
             delta1 <= 0;
             delta2 <= 0;
             m2_increment <= 0;
             shift <= 0;
         end else begin
             state <= state_next;
             valid_out <= valid_out_next;
             syn_count <= syn_count_next;
             pkt_count <= pkt_count_next;
             mean <= mean_next;
             m2 <= m2_next;
             delta1 <= delta1_next;
             delta2 <= delta2_next[DATAIN_WIDTH+SCALING -: MULT_WORD_SMALL_SIZE];
             m2_increment <= m2_increment_next;
             shift <= shift_next;
         end
     end             
     
     
     // Concatenate module
     concatenate
     #(
         .SCALING(SCALING),
         .RES_SHORT_WIDTH(RES_SHORT_WIDTH),
         .RES_LONG_WIDTH(RES_LONG_WIDTH),
         .OUTPUT_WIDTH(OUTPUT_WIDTH)
     ) concatenate_inst (
         .syn_count(syn_count),
         .pkt_count(pkt_count),
         .mean(mean[DATAIN_WIDTH+SCALING-1:0]),
         .m2(m2),
         .tuple_out(tuple_out_@EXTERN_NAME@_output_DATA)
     );
     
     assign tuple_out_@EXTERN_NAME@_output_VALID = valid_out;    
     
 endmodule

