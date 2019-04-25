`include "constant.v"
`timescale 1ns/1ps

module AES_core (
    input          clk      , // Clock
    input          rst_n    , // Asynchronous reset active low
    input  [127:0] round_key,
    input  [127:0] block    ,
    output [127:0] new_block
);

    function [127:0] add_round_key (input [127:0] block, input [127:0] key);

        begin
            add_round_key = block ^ key;
        end

    endfunction

    assign new_block = add_round_key(block, round_key);

endmodule


