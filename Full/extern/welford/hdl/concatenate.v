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
    //parameter RES_LONG_WIDTH   = 40,
    parameter OUTPUT_WIDTH     = 4*RES_SHORT_WIDTH /*+ RES_LONG_WIDTH*/
)(
    input           [RES_SHORT_WIDTH-1:0]                   syn_cnt,
    input           [RES_SHORT_WIDTH-1:0]                   pkt_cnt,
    input   signed  [DATAIN_WIDTH+SCALING:0]                mean,
    input   signed  [2*DATAIN_WIDTH+SCALING:0]              variance,
    output          [OUTPUT_WIDTH-1:0]                      tuple_out
);

wire    [RES_SHORT_WIDTH-1:0]   syn_cnt_out     =   syn_cnt[RES_SHORT_WIDTH-1:0];
wire    [RES_SHORT_WIDTH-1:0]   pkt_cnt_out     =   pkt_cnt[RES_SHORT_WIDTH-1:0];
wire    [RES_SHORT_WIDTH-1:0]   mean_out        =   {{(RES_SHORT_WIDTH-DATAIN_WIDTH){1'b0}}, mean[DATAIN_WIDTH+SCALING-1-:DATAIN_WIDTH]};
wire    [RES_SHORT_WIDTH-1:0]   variance_out         =   {variance[2*DATAIN_WIDTH+SCALING-1-:RES_SHORT_WIDTH]};

assign tuple_out = {syn_cnt_out, pkt_cnt_out, mean_out, variance_out};

endmodule

