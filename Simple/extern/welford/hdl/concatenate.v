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

`timescale 1ns / 1ps

module concatenate
#(
    parameter SCALING          = 32,
    parameter DATAIN_WIDTH     = 11,
    parameter RES_SHORT_WIDTH  = 24,
    parameter RES_LONG_WIDTH   = 40,
    parameter DELTA_SCALING    = 18 - DATAIN_WIDTH - 1,      // MULT_WORD_SMALL_SIZE = 18
    parameter OUTPUT_WIDTH     = 3*RES_SHORT_WIDTH + RES_LONG_WIDTH
)(
    input           [RES_SHORT_WIDTH-1:0]                   syn_count,
    input           [RES_SHORT_WIDTH-1:0]                   pkt_count,
    input           [DATAIN_WIDTH+SCALING-1:0]              mean,
    input   signed  [RES_LONG_WIDTH+2*DELTA_SCALING:0]      m2,
    output          [OUTPUT_WIDTH-1:0]                      tuple_out
);

wire    [RES_SHORT_WIDTH-DATAIN_WIDTH-1:0]      padding = 0;

wire    [RES_SHORT_WIDTH-1:0]   syn_count_out   =   syn_count[RES_SHORT_WIDTH-1:0];
wire    [RES_SHORT_WIDTH-1:0]   pkt_count_out   =   pkt_count[RES_SHORT_WIDTH-1:0];
wire    [RES_SHORT_WIDTH-1:0]   mean_out        =   {padding, mean[DATAIN_WIDTH+SCALING-1:SCALING]};
wire    [RES_LONG_WIDTH-1:0]    m2_out          =   m2[RES_LONG_WIDTH+2*DELTA_SCALING-1:2*DELTA_SCALING];

assign tuple_out = {syn_count_out, pkt_count_out, mean_out, m2_out};

endmodule

