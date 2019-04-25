`include "constant.v"
`timescale 1ns/1ps

module AES_core (
    input          clk      , // Clock
    input          rst_n    , // Asynchronous reset active low
    input  [127:0] round_key,
    input  [127:0] block    ,
    output [127:0] new_block
);

    function [127:0] subBytes (input [127:0] block);

        begin
            // find 1st hex
            subBytes[8*0+7:8*0] = constant.sbox[block[8*0+7:8*0]];
            subBytes[8*1+7:8*1] = constant.sbox[block[8*1+7:8*1]];
            subBytes[8*2+7:8*2] = constant.sbox[block[8*2+7:8*2]];
            subBytes[8*3+7:8*3] = constant.sbox[block[8*3+7:8*3]];

            subBytes[8*4+7:8*4] = constant.sbox[block[8*4+7:8*4]];
            subBytes[8*5+7:8*5] = constant.sbox[block[8*5+7:8*5]];
            subBytes[8*6+7:8*6] = constant.sbox[block[8*6+7:8*6]];
            subBytes[8*7+7:8*7] = constant.sbox[block[8*7+7:8*7]];

            subBytes[8*8+7:8*8] = constant.sbox[block[8*8+7:8*8]];
            subBytes[8*9+7:8*9] = constant.sbox[block[8*9+7:8*9]];
            subBytes[8*10+7:8*10] = constant.sbox[block[8*10+7:8*10]];
            subBytes[8*11+7:8*11] = constant.sbox[block[8*11+7:8*11]];

            subBytes[8*12+7:8*12] = constant.sbox[block[8*12+7:8*12]];
            subBytes[8*13+7:8*13] = constant.sbox[block[8*13+7:8*13]];
            subBytes[8*14+7:8*14] = constant.sbox[block[8*14+7:8*14]];
            subBytes[8*15+7:8*15] = constant.sbox[block[8*15+7:8*15]];
        end
    endfunction

    assign new_block = subBytes(block);

endmodule




