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


module multiplier
#(
    parameter MULT_WORD_SIZE = 18,
    parameter OUTPUT_WIDTH = 2*MULT_WORD_SIZE
)(
    input   signed [MULT_WORD_SIZE:0]       in_a, in_b,
    output  signed [OUTPUT_WIDTH:0]         out
);

assign out = in_a * in_b;

endmodule

