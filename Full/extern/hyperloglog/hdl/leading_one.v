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

module leading_one #(
    parameter INPUT_WIDTH = 20,
    parameter OUTPUT_WIDTH = $clog2(INPUT_WIDTH)
)(
    input   wire [INPUT_WIDTH-1  : 0] input_string,
    output  wire [OUTPUT_WIDTH-1 : 0] leading_one_position
);

reg  [INPUT_WIDTH-1 : 0]    convert_out;
wire [OUTPUT_WIDTH-1 : 0]   hamming_weight;


bitwise_adder_tree #(
    .INPUT_WIDTH(INPUT_WIDTH)
) bitwise_adder_tree_inst (
    .input_string(convert_out),
    .output_string(hamming_weight)
);
    
integer i;
always @(input_string) begin
    convert_out = input_string;
    for (i=1; i<=OUTPUT_WIDTH; i=i+1) begin
        convert_out = convert_out | (convert_out >> 2**(i-1));
    end  
end

localparam CONSTANT = INPUT_WIDTH+1;
assign leading_one_position = CONSTANT - hamming_weight;

endmodule
