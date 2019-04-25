`include "constant.v"
`timescale 1ns/1ps

module AES_core (
    input          clk      , // Clock
    input          rst_n    , // Asynchronous reset active low
    input  [127:0] block    ,
    output [127:0] new_block
);

    function [127:0] add_round_key (input [127:0] data, input [127:0] key);

        begin
            reg temp[127:0];
            temp[8*0+7:8*0] = data[8*0+7:8*0]^key[8*0+7:8*0];
            temp[8*1+7:8*1] = data[8*1+7:8*1]^key[8*1+7:8*1];
            temp[8*2+7:8*2] = data[8*2+7:8*2]^key[8*2+7:8*2];
            temp[8*3+7:8*3] = data[8*3+7:8*3]^key[8*3+7:8*3];

            temp[8*4+7:8*4] = data[8*4+7:8*4]^key[8*4+7:8*4];
            temp[8*5+7:8*5] = data[8*5+7:8*5]^key[8*5+7:8*5];
            temp[8*6+7:8*6] = data[8*6+7:8*6]^key[8*6+7:8*6];
            temp[8*7+7:8*7] = data[8*7+7:8*7]^key[8*7+7:8*7];

            temp[8*8+7:8*8] = data[8*8+7:8*8]^key[8*8+7:8*8];
            temp[8*9+7:8*9] = data[8*9+7:8*9]^key[8*9+7:8*9];
            temp[8*10+7:8*10] = data[8*10+7:8*10]^key[8*10+7:8*10];
            temp[8*11+7:8*11] = data[8*11+7:8*11]^key[8*11+7:8*11];

            temp[8*12+7:8*12] = data[8*12+7:8*12]^key[8*12+7:8*12];
            temp[8*13+7:8*13] = data[8*13+7:8*13]^key[8*13+7:8*13];
            temp[8*14+7:8*14] = data[8*14+7:8*14]^key[8*14+7:8*14];
            temp[8*15+7:8*15] = data[8*14+7:8*14]^key[8*14+7:8*14];

        end
    endfunction

    assign new_block = shiftRow(block);

endmodule


