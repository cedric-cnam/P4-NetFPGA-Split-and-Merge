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
 * hyperloglog
 *
 *  Descrioption: TODO
 *
 * - BUCKET_INDEX_WIDTH must be at least 4 (remember that HLL is precise for cardinalities >= (5/2)*m 
 * - HASH_WIDTH can be at maximum 24 --> we could have BUCKET_INDEX_WIDTH = 4 and RARITY_HASH_WIDTH = 16
 *
 */



`timescale 1 ps / 1 ps


module @MODULE_NAME@
#(
    parameter DATAIN_WIDTH          = @DATAIN_WIDTH@,
    parameter BUCKET_INDEX_WIDTH    = @BUCKET_INDEX_WIDTH@,
    parameter BUCKET_CONTENT_WIDTH  = @BUCKET_CONTENT_WIDTH@,
    parameter RARITY_HASH_WIDTH     = (2**BUCKET_CONTENT_WIDTH)-1,
    parameter HASH_WIDTH            = BUCKET_INDEX_WIDTH + RARITY_HASH_WIDTH,
    parameter OP_WIDTH              = 2,
    parameter INPUT_WIDTH           = DATAIN_WIDTH + OP_WIDTH + 1,
    parameter RESULT_WIDTH          = @RESULT_WIDTH@,
    parameter OUTPUT_WIDTH          = RESULT_WIDTH + BUCKET_INDEX_WIDTH
)
(
    // Data Path I/O
    input                                          clk_lookup,
    input                                          rst, 
    input                                          tuple_in_@EXTERN_NAME@_input_VALID,
    input   [INPUT_WIDTH-1:0]                      tuple_in_@EXTERN_NAME@_input_DATA,
    output                                         tuple_out_@EXTERN_NAME@_output_VALID,
    output  [OUTPUT_WIDTH-1:0]                     tuple_out_@EXTERN_NAME@_output_DATA
);
    
    
    //// Input buffer to hold requests ////
    // Parameters
    localparam L2_REQ_BUF_DEPTH = 3;
    // Signals
    wire                                statefulValid_fifo; 
    wire    [DATAIN_WIDTH-1:0]          data_fifo;
    wire    [OP_WIDTH-1:0]              opCode_fifo;
    wire    empty_fifo;
    wire    full_fifo;
    reg     rd_en_fifo;
    // Instantiation
    fallthrough_small_fifo
    #(
        .WIDTH(INPUT_WIDTH),
        .MAX_DEPTH_BITS(L2_REQ_BUF_DEPTH)
    )
    request_fifo
    (
       // Outputs
       .dout                           ({statefulValid_fifo, data_fifo, opCode_fifo}),
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

    //// Read-first BRAM to implement rarity buckets ////
    // Signals
    reg                                 we_bram;
    reg  [BUCKET_INDEX_WIDTH-1:0]       addr_in_bram, addr_in_bram_r, addr_in_bram_r_next;
    reg  [BUCKET_CONTENT_WIDTH-1:0]     data_in_bram;
    wire [BUCKET_CONTENT_WIDTH-1:0]     data_out_bram;
    // Instantiation
    true_dp_bram_readfirst
    #(
        .L2_DEPTH(BUCKET_INDEX_WIDTH),
        .WIDTH(BUCKET_CONTENT_WIDTH)
    ) rarity_bram
    (
        .clk               (clk_lookup),
        // data plane R/W interface
        .we2               (we_bram),
        .en2               (1'b1),
        .addr2             (addr_in_bram),
        .din2              (data_in_bram),
        .rst2              (rst),
        .regce2            (1'b1),
        .dout2             (data_out_bram),

        .we1               (1'b0),
        .en1               (1'b0),
        .addr1             ({(BUCKET_INDEX_WIDTH){1'b0}}),
        .din1              ({(BUCKET_CONTENT_WIDTH){1'b0}}),
        .rst1              (rst),
        .regce1            (1'b0),
        .dout1             ()        
    );
    
    
    //// "Universal hashing" with multiply and shift ////
    // Signals
    wire [RARITY_HASH_WIDTH-1:0]    rarity_hash;
    wire [BUCKET_INDEX_WIDTH-1:0]   address_hash;
    // Instantiation
    hash_function#(
        .DATAIN_WIDTH(DATAIN_WIDTH),
        .RARITY_HASH_WIDTH(RARITY_HASH_WIDTH),
        .BUCKET_INDEX_WIDTH(BUCKET_INDEX_WIDTH)
    ) hash_function_inst (
        .in_hash(data_fifo),
        .rarity_hash(rarity_hash),
        .address_hash(address_hash)
    );
    
    
    //// Leading One Detector to determine HyperLogLog's rarity ////
    // Signals
    reg  [RARITY_HASH_WIDTH-1:0]        in_rarity_r;
    wire  [BUCKET_CONTENT_WIDTH-1:0]    out_rarity;
    // Instantiation
    leading_one #(
        .INPUT_WIDTH(RARITY_HASH_WIDTH)
    ) rarity_lod (
        .input_string(in_rarity_r),
        .leading_one_position(out_rarity)
    );
    
    
   /* State Machine */
   // Parameters
   localparam DEFAULT_RECIPROCAL = 2**(RARITY_HASH_WIDTH-1);
   localparam RESED_WORD = {BUCKET_CONTENT_WIDTH{1'b0}};
   // opCodes
   localparam OP_READ      = 2'd0;
   localparam OP_UPDATE    = 2'd1;
   localparam OP_RESET     = 2'd2;
   // States
   localparam StIdle        = 3'd0;
   localparam StHllUpdate   = 3'd1;
   localparam StComputeSum  = 3'd2;
   localparam StWriteResult = 3'd3;
   localparam StReset       = 3'd4;
   // Signals
   reg  [2:0]                      state_r, state_r_next;
   reg  [1:0]                      cycle_cnt_r, cycle_cnt_r_next;
   reg  [RARITY_HASH_WIDTH-1:0]    reciprocal;
   reg  [OUTPUT_WIDTH-1:0]         result_r, result_r_next;
   reg  [BUCKET_INDEX_WIDTH-1:0]   empty_buckets_r, empty_buckets_r_next;
   reg                             valid_out;  
   // Logic
   always @(*) begin
      //// default values
      // SM Signals
      state_r_next = state_r;
      cycle_cnt_r_next = cycle_cnt_r;
      rd_en_fifo = 0;
      // BRAM Signals
      we_bram = 0;
      addr_in_bram = addr_in_bram_r;
      addr_in_bram_r_next = addr_in_bram_r;
      data_in_bram = 0; 
      // HLL Read Signals      
      reciprocal = 0;
      result_r_next = result_r;
      empty_buckets_r_next = empty_buckets_r;     
      valid_out = 0;
      

      //// SM Description
      case(state_r)       
         StIdle: begin
            cycle_cnt_r_next = 0;
            // reset the result register when returning to idle state
            result_r_next = 0;
            empty_buckets_r_next = 0;
            if (~empty_fifo) begin
               rd_en_fifo = 1;
               if (statefulValid_fifo) begin
                  if (opCode_fifo == OP_UPDATE) begin
                     // We compute the hash function to get the bucket index and the rarity hash value.
                     // We save the bucket index to read the last rarity stored in the next clk cycles
                     // We save the rarity_hash value as input for the leading one position counter
                     addr_in_bram             = address_hash;
                     addr_in_bram_r_next      = address_hash;
                     state_r_next = StHllUpdate;
                  end else if (opCode_fifo == OP_READ) begin
                     addr_in_bram_r_next = 0;
                     state_r_next = StComputeSum;
                  end else if (opCode_fifo == OP_RESET) begin
                     addr_in_bram_r_next = 0;
                     state_r_next = StReset;
                  end else begin
                     valid_out = 1;
                  end
               end else begin
                  valid_out = 1;
               end
            end
         end

         StHllUpdate: begin
            // 2 cycle BRAM read latency
            if (cycle_cnt_r == 1'b1) begin
                if (out_rarity > data_out_bram) begin
                    we_bram = 1;
                    data_in_bram = out_rarity;
                end
                state_r_next = StIdle;
                valid_out = 1;
            end else begin
                cycle_cnt_r_next = cycle_cnt_r + 1;
            end
         end
            
         StComputeSum: begin
            // We iteratively read from all the buckets
            addr_in_bram_r_next = addr_in_bram_r + 1;
            if ( addr_in_bram_r == (2**BUCKET_INDEX_WIDTH - 1) ) begin
                state_r_next = StWriteResult;
            end
            // Start summing the normalized reciprocal (amplified by 2^RARITY_HASH_WIDTH) after two cycles
            if (addr_in_bram_r >= 1) begin
                reciprocal = DEFAULT_RECIPROCAL >> data_out_bram;
                if (data_out_bram == 0) begin    
                    empty_buckets_r_next = empty_buckets_r + 1;
                end
                result_r_next = result_r + reciprocal;
            end
            
         end
         
         StWriteResult : begin
            // Wait two cycles to take the BRAM latency into account
            reciprocal = DEFAULT_RECIPROCAL >> data_out_bram;
            if (data_out_bram == 0) begin    
                empty_buckets_r_next = empty_buckets_r + 1;
            end
            result_r_next = result_r + reciprocal;
            if (cycle_cnt_r == 2'b00) begin
                cycle_cnt_r_next = cycle_cnt_r + 1;
            end else begin
                // Send the output, reset the cycle counter and return to idle state
                valid_out = 1;
                state_r_next = StIdle;
            end
         end
         
         StReset: begin
            we_bram = 1'b1;
            data_in_bram = RESED_WORD;
            addr_in_bram_r_next = addr_in_bram_r + 1; //reset RAM word by word
            if (addr_in_bram_r == 2**BUCKET_INDEX_WIDTH-1) begin
                // Stop when the buckets are over
                state_r_next = StIdle;
                valid_out = 1;
            end
         end 
         
      endcase   // case(state_r)         
   end          // State Machine

   always @(posedge clk_lookup) begin
      if(rst) begin
         state_r <= StIdle;     
      end else begin
         state_r <= state_r_next;
      end
   end
   
   always @(posedge clk_lookup) begin
        // State Machine Registers
        cycle_cnt_r <= cycle_cnt_r_next;
        // BRAM Register
        addr_in_bram_r <= addr_in_bram_r_next;
        in_rarity_r <= rarity_hash;
        // Output registers
        result_r <= result_r_next;
        empty_buckets_r <= empty_buckets_r_next;
   end
   
   assign tuple_out_@EXTERN_NAME@_output_VALID = valid_out;
   assign tuple_out_@EXTERN_NAME@_output_DATA  = {result_r_next,empty_buckets_r_next};


endmodule
