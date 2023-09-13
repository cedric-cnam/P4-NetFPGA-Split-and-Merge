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

`timescale 1ps / 1ps

module hash_function#(
    parameter DATAIN_WIDTH = 32,
    parameter RARITY_HASH_WIDTH = 7,
    parameter BUCKET_INDEX_WIDTH = 7,
    parameter HASH_WIDTH = BUCKET_INDEX_WIDTH + RARITY_HASH_WIDTH
)(
    input   wire [DATAIN_WIDTH-1       : 0]   in_hash,
    output  wire [RARITY_HASH_WIDTH-1  : 0]   rarity_hash,
    output  wire [BUCKET_INDEX_WIDTH-1 : 0]   address_hash
);

localparam MULT_WORD_SIZE = 24, MULT_WORD_SMALL_SIZE = 18;  //DSP48E1 has 18*24 multiplier
localparam SLICE_EXCESS_SIZE = MULT_WORD_SIZE - (DATAIN_WIDTH/2);

// Input slicing signals
reg  [MULT_WORD_SIZE-1:0]       key_slice[1:0];

// Multiplier signals
reg  [HASH_WIDTH-1:0]           mult_result[1:0];
wire [MULT_WORD_SMALL_SIZE-1:0] hash_seeds[1:0];
assign hash_seeds[0] = 18'h041a7;
assign hash_seeds[1] = 18'h23af1;

always @(in_hash) begin
    // Split input word
    key_slice[0] = {{SLICE_EXCESS_SIZE{1'b0}}, in_hash[(DATAIN_WIDTH/2)-1 : 0]};
    key_slice[1] = {{SLICE_EXCESS_SIZE{1'b0}}, in_hash[DATAIN_WIDTH-1 : DATAIN_WIDTH/2]};
    // Compute multiplications
    mult_result[0] = ( key_slice[0] * hash_seeds[0] ) >> ( MULT_WORD_SIZE - HASH_WIDTH );
    mult_result[1] = ( key_slice[1] * hash_seeds[1] ) >> ( MULT_WORD_SIZE - HASH_WIDTH );
end

// Compute XOR
wire    [HASH_WIDTH-1:0]    hash_result;
assign  hash_result = mult_result[0] ^ mult_result[1];

// Assign output signals
assign  rarity_hash  = hash_result [ RARITY_HASH_WIDTH-1  : 0                  ];
assign  address_hash = hash_result [ HASH_WIDTH-1         : RARITY_HASH_WIDTH  ];

endmodule
