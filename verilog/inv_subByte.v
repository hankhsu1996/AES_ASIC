`include "constant.v"
`timescale 1ns/1ps

module AES_core (
    input          clk      , // Clock
    input          rst_n    , // Asynchronous reset active low
    input  [127:0] round_key,
    input  [127:0] block    ,
    output [127:0] new_block
);

    function [127:0] inv_subBytes (input [127:0] block);

        begin
            // find 1st hex
            inv_subBytes[8*0+7:8*0] = constant.inv_sbox[block[8*0+7:8*0]];
            inv_subBytes[8*1+7:8*1] = constant.inv_sbox[block[8*1+7:8*1]];
            inv_subBytes[8*2+7:8*2] = constant.inv_sbox[block[8*2+7:8*2]];
            inv_subBytes[8*3+7:8*3] = constant.inv_sbox[block[8*3+7:8*3]];

            inv_subBytes[8*4+7:8*4] = constant.inv_sbox[block[8*4+7:8*4]];
            inv_subBytes[8*5+7:8*5] = constant.inv_sbox[block[8*5+7:8*5]];
            inv_subBytes[8*6+7:8*6] = constant.inv_sbox[block[8*6+7:8*6]];
            inv_subBytes[8*7+7:8*7] = constant.inv_sbox[block[8*7+7:8*7]];

            inv_subBytes[8*8+7:8*8] = constant.inv_sbox[block[8*8+7:8*8]];
            inv_subBytes[8*9+7:8*9] = constant.inv_sbox[block[8*9+7:8*9]];
            inv_subBytes[8*10+7:8*10] = constant.inv_sbox[block[8*10+7:8*10]];
            inv_subBytes[8*11+7:8*11] = constant.inv_sbox[block[8*11+7:8*11]];

            inv_subBytes[8*12+7:8*12] = constant.inv_sbox[block[8*12+7:8*12]];
            inv_subBytes[8*13+7:8*13] = constant.inv_sbox[block[8*13+7:8*13]];
            inv_subBytes[8*14+7:8*14] = constant.inv_sbox[block[8*14+7:8*14]];
            inv_subBytes[8*15+7:8*15] = constant.inv_sbox[block[8*15+7:8*15]];
        end
    endfunction

    assign new_block = inv_subBytes(block);

endmodule




