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

module bitwise_adder_tree 
#(
    parameter INPUT_WIDTH = 20,
    parameter OUTPUT_WIDTH = $clog2(INPUT_WIDTH),
    parameter STAGES_NUM = OUTPUT_WIDTH+1,
    parameter INPUT_WIDTH_ROUND = 2 ** STAGES_NUM
)(
    input   wire [INPUT_WIDTH-1  : 0] input_string,
    output  wire [OUTPUT_WIDTH-1 : 0] output_string
);

wire [OUTPUT_WIDTH-1:0]                     data    [STAGES_NUM-1:0][INPUT_WIDTH_ROUND-1:0];

genvar stage, adder;
generate
    for( stage = 0; stage <= STAGES_NUM; stage=stage+1 ) begin: stage_gen
    
        localparam ADDER_NUM = INPUT_WIDTH_ROUND >> stage;
    
        // Stage 0 is just the input
        if (stage == 0) begin
            for( adder = 0; adder < ADDER_NUM; adder=adder+1 ) begin: input_gen
                if( adder < INPUT_WIDTH ) begin
                    assign data[stage][adder] = input_string[adder];
                end else begin
                    assign data[stage][adder] = 0;
                end
            end // input_gen
        end else begin
        // The rest of the stages are adders
            for( adder = 0; adder < ADDER_NUM; adder=adder+1 ) begin: adder_gen
                assign data[stage][adder] = data[stage-1][2*adder] + data[stage-1][2*adder+1];
            end // adder_gen
        end
    end // stage_gen
endgenerate

assign output_string = data[STAGES_NUM-1][0];

endmodule
