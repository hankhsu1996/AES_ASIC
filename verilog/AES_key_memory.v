`timescale 1ns / 1ps
`include "sbox.v"
`include "constant.v"


module AES_key_memory (
    input          clk   , // Clock
    input          rst_n , // Asynchronous reset active low
    input  [  3:0] round ,
    input  [127:0] key   ,
    output [127:0] keyout
);

    reg  [127:0] keyout      ;
    wire [127:0] keytem[10:0];

    assign keytem[0] = key;

    KeyGeneration a1 (4'b0000,keytem[0],keytem[1]);
    KeyGeneration a2 (4'b0001,keytem[1],keytem[2]);
    KeyGeneration a3 (4'b0010,keytem[2],keytem[3]);
    KeyGeneration a4 (4'b0011,keytem[3],keytem[4]);
    KeyGeneration a5 (4'b0100,keytem[4],keytem[5]);
    KeyGeneration a6 (4'b0101,keytem[5],keytem[6]);
    KeyGeneration a7 (4'b0110,keytem[6],keytem[7]);
    KeyGeneration a8 (4'b0111,keytem[7],keytem[8]);
    KeyGeneration a9 (4'b1000,keytem[8],keytem[9]);
    KeyGeneration a10 (4'b1001,keytem[9],keytem[10]);

    always @(posedge clk) begin
        keyout <= keytem[round];
    end
endmodule // KeyTotal


module KeyGeneration (
    input  [  3:0] rc    ,
    input  [127:0] key   ,
    output [127:0] keyout
);

    wire [31:0] w0,w1,w2,w3,tem;

    assign w0             = key[127:96];
    assign w1             = key[95:64];
    assign w2             = key[63:32];
    assign w3             = key[31:0];
    assign keyout[127:96] = w0 ^ tem ^ rcon(rc);
    assign keyout[95:64]  = w0 ^ tem ^ rcon(rc)^ w1;
    assign keyout[63:32]  = w0 ^ tem ^ rcon(rc)^ w1 ^ w2;
    assign keyout[31:0]   = w0 ^ tem ^ rcon(rc)^ w1 ^ w2 ^ w3;

    
    assign tem[31:24] = constant.sbox[w3[23:16]];
    
    // sbox a1 (.a(w3[23:16]), .c(tem[31:24]));
    sbox a2 (.a(w3[15:8]), .c(tem[23:16]));
    sbox a3 (.a(w3[7:0]), .c(tem[15:8]));
    sbox a4 (.a(w3[31:24]), .c(tem[7:0]));

    function [31:0] rcon(input [3:0] rc);
        case(rc)
            4'h0    : rcon = 32'h01_00_00_00;
            4'h1    : rcon = 32'h02_00_00_00;
            4'h2    : rcon = 32'h04_00_00_00;
            4'h3    : rcon = 32'h08_00_00_00;
            4'h4    : rcon = 32'h10_00_00_00;
            4'h5    : rcon = 32'h20_00_00_00;
            4'h6    : rcon = 32'h40_00_00_00;
            4'h7    : rcon = 32'h80_00_00_00;
            4'h8    : rcon = 32'h1b_00_00_00;
            4'h9    : rcon = 32'h36_00_00_00;
            default : rcon = 32'h00_00_00_00;
        endcase // rc
    endfunction // rcon
endmodule // KeyGeneration

