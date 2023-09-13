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

module approx_mult_2x2
(
    input   wire [1:0]   in_a, in_b,
    output  wire [2:0]   out
);

assign out[0] = in_a[0] & in_b[0];
assign out[1] = (in_a[0] & in_b[1]) | (in_a[1] & in_b[0]);
assign out[2] = in_a[1] & in_b[1];

endmodule


