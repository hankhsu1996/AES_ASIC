// for higher level module, v may be double included
// uncomment to run testbench
// `include "v"
`timescale 1ns/1ps

module AES_decipher (
    input          clk      , // Clock
    input          rst_n    , // Asynchronous reset active low
    input          next     , // Use next to indicate the next request for decipher
    input          keylen   , // Use keylen to indicate AES128 or AES256, not yet implemented
    output [  3:0] round    , // Use round to request the round key
    input  [127:0] round_key,
    input  [127:0] block    ,
    output [127:0] new_block,
    output         ready
);

    // ------------------------------------------------------
    // ------------------- all parameters -------------------
    // ------------------------------------------------------

    // define control state
    localparam CTRL_IDLE  = 3'h0;
    localparam CTRL_INIT  = 3'h1;
    localparam CTRL_MAIN  = 3'h2;
    localparam CTRL_FINAL = 3'h3;

    localparam AES_128_BIT_KEY = 1'h0;
    localparam AES_256_BIT_KEY = 1'h1;

    localparam AES128_ROUNDS = 4'ha;
    localparam AES256_ROUNDS = 4'he;

    // define update type
    localparam NO_UPDATE    = 3'h0;
    localparam INIT_UPDATE  = 3'h1;
    localparam MAIN_UPDATE  = 3'h2;
    localparam FINAL_UPDATE = 3'h3;


    wire [7:0] inv_sbox[255:0];

    assign inv_sbox[8'h00] = 8'h52;
    assign inv_sbox[8'h01] = 8'h09;
    assign inv_sbox[8'h02] = 8'h6a;
    assign inv_sbox[8'h03] = 8'hd5;
    assign inv_sbox[8'h04] = 8'h30;
    assign inv_sbox[8'h05] = 8'h36;
    assign inv_sbox[8'h06] = 8'ha5;
    assign inv_sbox[8'h07] = 8'h38;
    assign inv_sbox[8'h08] = 8'hbf;
    assign inv_sbox[8'h09] = 8'h40;
    assign inv_sbox[8'h0a] = 8'ha3;
    assign inv_sbox[8'h0b] = 8'h9e;
    assign inv_sbox[8'h0c] = 8'h81;
    assign inv_sbox[8'h0d] = 8'hf3;
    assign inv_sbox[8'h0e] = 8'hd7;
    assign inv_sbox[8'h0f] = 8'hfb;
    assign inv_sbox[8'h10] = 8'h7c;
    assign inv_sbox[8'h11] = 8'he3;
    assign inv_sbox[8'h12] = 8'h39;
    assign inv_sbox[8'h13] = 8'h82;
    assign inv_sbox[8'h14] = 8'h9b;
    assign inv_sbox[8'h15] = 8'h2f;
    assign inv_sbox[8'h16] = 8'hff;
    assign inv_sbox[8'h17] = 8'h87;
    assign inv_sbox[8'h18] = 8'h34;
    assign inv_sbox[8'h19] = 8'h8e;
    assign inv_sbox[8'h1a] = 8'h43;
    assign inv_sbox[8'h1b] = 8'h44;
    assign inv_sbox[8'h1c] = 8'hc4;
    assign inv_sbox[8'h1d] = 8'hde;
    assign inv_sbox[8'h1e] = 8'he9;
    assign inv_sbox[8'h1f] = 8'hcb;
    assign inv_sbox[8'h20] = 8'h54;
    assign inv_sbox[8'h21] = 8'h7b;
    assign inv_sbox[8'h22] = 8'h94;
    assign inv_sbox[8'h23] = 8'h32;
    assign inv_sbox[8'h24] = 8'ha6;
    assign inv_sbox[8'h25] = 8'hc2;
    assign inv_sbox[8'h26] = 8'h23;
    assign inv_sbox[8'h27] = 8'h3d;
    assign inv_sbox[8'h28] = 8'hee;
    assign inv_sbox[8'h29] = 8'h4c;
    assign inv_sbox[8'h2a] = 8'h95;
    assign inv_sbox[8'h2b] = 8'h0b;
    assign inv_sbox[8'h2c] = 8'h42;
    assign inv_sbox[8'h2d] = 8'hfa;
    assign inv_sbox[8'h2e] = 8'hc3;
    assign inv_sbox[8'h2f] = 8'h4e;
    assign inv_sbox[8'h30] = 8'h08;
    assign inv_sbox[8'h31] = 8'h2e;
    assign inv_sbox[8'h32] = 8'ha1;
    assign inv_sbox[8'h33] = 8'h66;
    assign inv_sbox[8'h34] = 8'h28;
    assign inv_sbox[8'h35] = 8'hd9;
    assign inv_sbox[8'h36] = 8'h24;
    assign inv_sbox[8'h37] = 8'hb2;
    assign inv_sbox[8'h38] = 8'h76;
    assign inv_sbox[8'h39] = 8'h5b;
    assign inv_sbox[8'h3a] = 8'ha2;
    assign inv_sbox[8'h3b] = 8'h49;
    assign inv_sbox[8'h3c] = 8'h6d;
    assign inv_sbox[8'h3d] = 8'h8b;
    assign inv_sbox[8'h3e] = 8'hd1;
    assign inv_sbox[8'h3f] = 8'h25;
    assign inv_sbox[8'h40] = 8'h72;
    assign inv_sbox[8'h41] = 8'hf8;
    assign inv_sbox[8'h42] = 8'hf6;
    assign inv_sbox[8'h43] = 8'h64;
    assign inv_sbox[8'h44] = 8'h86;
    assign inv_sbox[8'h45] = 8'h68;
    assign inv_sbox[8'h46] = 8'h98;
    assign inv_sbox[8'h47] = 8'h16;
    assign inv_sbox[8'h48] = 8'hd4;
    assign inv_sbox[8'h49] = 8'ha4;
    assign inv_sbox[8'h4a] = 8'h5c;
    assign inv_sbox[8'h4b] = 8'hcc;
    assign inv_sbox[8'h4c] = 8'h5d;
    assign inv_sbox[8'h4d] = 8'h65;
    assign inv_sbox[8'h4e] = 8'hb6;
    assign inv_sbox[8'h4f] = 8'h92;
    assign inv_sbox[8'h50] = 8'h6c;
    assign inv_sbox[8'h51] = 8'h70;
    assign inv_sbox[8'h52] = 8'h48;
    assign inv_sbox[8'h53] = 8'h50;
    assign inv_sbox[8'h54] = 8'hfd;
    assign inv_sbox[8'h55] = 8'hed;
    assign inv_sbox[8'h56] = 8'hb9;
    assign inv_sbox[8'h57] = 8'hda;
    assign inv_sbox[8'h58] = 8'h5e;
    assign inv_sbox[8'h59] = 8'h15;
    assign inv_sbox[8'h5a] = 8'h46;
    assign inv_sbox[8'h5b] = 8'h57;
    assign inv_sbox[8'h5c] = 8'ha7;
    assign inv_sbox[8'h5d] = 8'h8d;
    assign inv_sbox[8'h5e] = 8'h9d;
    assign inv_sbox[8'h5f] = 8'h84;
    assign inv_sbox[8'h60] = 8'h90;
    assign inv_sbox[8'h61] = 8'hd8;
    assign inv_sbox[8'h62] = 8'hab;
    assign inv_sbox[8'h63] = 8'h00;
    assign inv_sbox[8'h64] = 8'h8c;
    assign inv_sbox[8'h65] = 8'hbc;
    assign inv_sbox[8'h66] = 8'hd3;
    assign inv_sbox[8'h67] = 8'h0a;
    assign inv_sbox[8'h68] = 8'hf7;
    assign inv_sbox[8'h69] = 8'he4;
    assign inv_sbox[8'h6a] = 8'h58;
    assign inv_sbox[8'h6b] = 8'h05;
    assign inv_sbox[8'h6c] = 8'hb8;
    assign inv_sbox[8'h6d] = 8'hb3;
    assign inv_sbox[8'h6e] = 8'h45;
    assign inv_sbox[8'h6f] = 8'h06;
    assign inv_sbox[8'h70] = 8'hd0;
    assign inv_sbox[8'h71] = 8'h2c;
    assign inv_sbox[8'h72] = 8'h1e;
    assign inv_sbox[8'h73] = 8'h8f;
    assign inv_sbox[8'h74] = 8'hca;
    assign inv_sbox[8'h75] = 8'h3f;
    assign inv_sbox[8'h76] = 8'h0f;
    assign inv_sbox[8'h77] = 8'h02;
    assign inv_sbox[8'h78] = 8'hc1;
    assign inv_sbox[8'h79] = 8'haf;
    assign inv_sbox[8'h7a] = 8'hbd;
    assign inv_sbox[8'h7b] = 8'h03;
    assign inv_sbox[8'h7c] = 8'h01;
    assign inv_sbox[8'h7d] = 8'h13;
    assign inv_sbox[8'h7e] = 8'h8a;
    assign inv_sbox[8'h7f] = 8'h6b;
    assign inv_sbox[8'h80] = 8'h3a;
    assign inv_sbox[8'h81] = 8'h91;
    assign inv_sbox[8'h82] = 8'h11;
    assign inv_sbox[8'h83] = 8'h41;
    assign inv_sbox[8'h84] = 8'h4f;
    assign inv_sbox[8'h85] = 8'h67;
    assign inv_sbox[8'h86] = 8'hdc;
    assign inv_sbox[8'h87] = 8'hea;
    assign inv_sbox[8'h88] = 8'h97;
    assign inv_sbox[8'h89] = 8'hf2;
    assign inv_sbox[8'h8a] = 8'hcf;
    assign inv_sbox[8'h8b] = 8'hce;
    assign inv_sbox[8'h8c] = 8'hf0;
    assign inv_sbox[8'h8d] = 8'hb4;
    assign inv_sbox[8'h8e] = 8'he6;
    assign inv_sbox[8'h8f] = 8'h73;
    assign inv_sbox[8'h90] = 8'h96;
    assign inv_sbox[8'h91] = 8'hac;
    assign inv_sbox[8'h92] = 8'h74;
    assign inv_sbox[8'h93] = 8'h22;
    assign inv_sbox[8'h94] = 8'he7;
    assign inv_sbox[8'h95] = 8'had;
    assign inv_sbox[8'h96] = 8'h35;
    assign inv_sbox[8'h97] = 8'h85;
    assign inv_sbox[8'h98] = 8'he2;
    assign inv_sbox[8'h99] = 8'hf9;
    assign inv_sbox[8'h9a] = 8'h37;
    assign inv_sbox[8'h9b] = 8'he8;
    assign inv_sbox[8'h9c] = 8'h1c;
    assign inv_sbox[8'h9d] = 8'h75;
    assign inv_sbox[8'h9e] = 8'hdf;
    assign inv_sbox[8'h9f] = 8'h6e;
    assign inv_sbox[8'ha0] = 8'h47;
    assign inv_sbox[8'ha1] = 8'hf1;
    assign inv_sbox[8'ha2] = 8'h1a;
    assign inv_sbox[8'ha3] = 8'h71;
    assign inv_sbox[8'ha4] = 8'h1d;
    assign inv_sbox[8'ha5] = 8'h29;
    assign inv_sbox[8'ha6] = 8'hc5;
    assign inv_sbox[8'ha7] = 8'h89;
    assign inv_sbox[8'ha8] = 8'h6f;
    assign inv_sbox[8'ha9] = 8'hb7;
    assign inv_sbox[8'haa] = 8'h62;
    assign inv_sbox[8'hab] = 8'h0e;
    assign inv_sbox[8'hac] = 8'haa;
    assign inv_sbox[8'had] = 8'h18;
    assign inv_sbox[8'hae] = 8'hbe;
    assign inv_sbox[8'haf] = 8'h1b;
    assign inv_sbox[8'hb0] = 8'hfc;
    assign inv_sbox[8'hb1] = 8'h56;
    assign inv_sbox[8'hb2] = 8'h3e;
    assign inv_sbox[8'hb3] = 8'h4b;
    assign inv_sbox[8'hb4] = 8'hc6;
    assign inv_sbox[8'hb5] = 8'hd2;
    assign inv_sbox[8'hb6] = 8'h79;
    assign inv_sbox[8'hb7] = 8'h20;
    assign inv_sbox[8'hb8] = 8'h9a;
    assign inv_sbox[8'hb9] = 8'hdb;
    assign inv_sbox[8'hba] = 8'hc0;
    assign inv_sbox[8'hbb] = 8'hfe;
    assign inv_sbox[8'hbc] = 8'h78;
    assign inv_sbox[8'hbd] = 8'hcd;
    assign inv_sbox[8'hbe] = 8'h5a;
    assign inv_sbox[8'hbf] = 8'hf4;
    assign inv_sbox[8'hc0] = 8'h1f;
    assign inv_sbox[8'hc1] = 8'hdd;
    assign inv_sbox[8'hc2] = 8'ha8;
    assign inv_sbox[8'hc3] = 8'h33;
    assign inv_sbox[8'hc4] = 8'h88;
    assign inv_sbox[8'hc5] = 8'h07;
    assign inv_sbox[8'hc6] = 8'hc7;
    assign inv_sbox[8'hc7] = 8'h31;
    assign inv_sbox[8'hc8] = 8'hb1;
    assign inv_sbox[8'hc9] = 8'h12;
    assign inv_sbox[8'hca] = 8'h10;
    assign inv_sbox[8'hcb] = 8'h59;
    assign inv_sbox[8'hcc] = 8'h27;
    assign inv_sbox[8'hcd] = 8'h80;
    assign inv_sbox[8'hce] = 8'hec;
    assign inv_sbox[8'hcf] = 8'h5f;
    assign inv_sbox[8'hd0] = 8'h60;
    assign inv_sbox[8'hd1] = 8'h51;
    assign inv_sbox[8'hd2] = 8'h7f;
    assign inv_sbox[8'hd3] = 8'ha9;
    assign inv_sbox[8'hd4] = 8'h19;
    assign inv_sbox[8'hd5] = 8'hb5;
    assign inv_sbox[8'hd6] = 8'h4a;
    assign inv_sbox[8'hd7] = 8'h0d;
    assign inv_sbox[8'hd8] = 8'h2d;
    assign inv_sbox[8'hd9] = 8'he5;
    assign inv_sbox[8'hda] = 8'h7a;
    assign inv_sbox[8'hdb] = 8'h9f;
    assign inv_sbox[8'hdc] = 8'h93;
    assign inv_sbox[8'hdd] = 8'hc9;
    assign inv_sbox[8'hde] = 8'h9c;
    assign inv_sbox[8'hdf] = 8'hef;
    assign inv_sbox[8'he0] = 8'ha0;
    assign inv_sbox[8'he1] = 8'he0;
    assign inv_sbox[8'he2] = 8'h3b;
    assign inv_sbox[8'he3] = 8'h4d;
    assign inv_sbox[8'he4] = 8'hae;
    assign inv_sbox[8'he5] = 8'h2a;
    assign inv_sbox[8'he6] = 8'hf5;
    assign inv_sbox[8'he7] = 8'hb0;
    assign inv_sbox[8'he8] = 8'hc8;
    assign inv_sbox[8'he9] = 8'heb;
    assign inv_sbox[8'hea] = 8'hbb;
    assign inv_sbox[8'heb] = 8'h3c;
    assign inv_sbox[8'hec] = 8'h83;
    assign inv_sbox[8'hed] = 8'h53;
    assign inv_sbox[8'hee] = 8'h99;
    assign inv_sbox[8'hef] = 8'h61;
    assign inv_sbox[8'hf0] = 8'h17;
    assign inv_sbox[8'hf1] = 8'h2b;
    assign inv_sbox[8'hf2] = 8'h04;
    assign inv_sbox[8'hf3] = 8'h7e;
    assign inv_sbox[8'hf4] = 8'hba;
    assign inv_sbox[8'hf5] = 8'h77;
    assign inv_sbox[8'hf6] = 8'hd6;
    assign inv_sbox[8'hf7] = 8'h26;
    assign inv_sbox[8'hf8] = 8'he1;
    assign inv_sbox[8'hf9] = 8'h69;
    assign inv_sbox[8'hfa] = 8'h14;
    assign inv_sbox[8'hfb] = 8'h63;
    assign inv_sbox[8'hfc] = 8'h55;
    assign inv_sbox[8'hfd] = 8'h21;
    assign inv_sbox[8'hfe] = 8'h0c;
    assign inv_sbox[8'hff] = 8'h7d;


    // the register to store control state information
    reg [2:0] main_ctrl_reg;
    reg [2:0] main_ctrl_new;
    reg       ready_reg    ;
    reg       ready_new    ;

    // reg to save round controller information
    reg [3:0] round_ctrl_reg;
    reg [3:0] round_ctrl_new;
    reg       round_ctrl_dec;

    // the register to indicate what kind of round (init, main and final)
    reg [  1:0] update_type;
    reg [127:0] block_reg  ;
    reg [127:0] block_new  ;

    // Concurrent connectivity for ports
    assign ready     = ready_reg;
    assign round     = round_ctrl_reg;
    assign new_block = block_reg;

    // ------------------------------------------------------
    // ---------------- basic four functions ----------------
    // ------------------------------------------------------

    function [7:0] mul2(input [7:0] block);
        // if the leftmost is 1, XOR 0x1B
        // if not, do nothing
        mul2 = {block[6 : 0], 1'b0} ^ (8'h1b & {8{block[7]}});
    endfunction

    function [7:0] mul4(input [7:0] block);
        mul4 = mul2(mul2(block));
    endfunction

    function [7:0] mul8(input [7:0] block);
        mul8 = mul4(mul2(block));
    endfunction

    function [7:0] mul9(input [7:0] block);
        mul9 = mul8(block) ^ block;
    endfunction


    function [7:0] mul11(input [7:0] block);
        mul11 = mul2(mul4(block) ^ block) ^ block;
    endfunction


    function [7:0] mul13(input [7:0] block);
        mul13 = mul4(mul2(block) ^ block) ^ block;
    endfunction


    function [7:0] mul14(input [7:0] block);
        mul14 = mul2(mul2(mul2(block) ^ block) ^ block);
    endfunction

    // function [7:0] add(input [7:0] a, input [7:0] b);
    //     reg [8:0] temp;
    //     begin
    //         temp = a + b;

    //         if (temp > 8'hff) begin
    //             temp = temp - 8'hff;
    //         end

    //         add[7:0] = temp[7:0];
    //     end
    // endfunction

    // function [7:0] lookupEL(input [7:0] block, input [7:0] constant);
    //     if (block == 8'h00) begin
    //         lookupEL = 8'h00;
    //     end else begin
    //         lookupEL = E[add(L[block], L[constant])];
    //     end
    // endfunction

    function [31:0] inv_mixColumn32(input [31:0] block);
        reg [7:0] test;
        begin

            // inv_mixColumn32[31:24] = lookupEL(block[7:0], 8'h09) ^ lookupEL(block[15:8], 8'h0d) ^ lookupEL(block[23:16], 8'h0b) ^ lookupEL(block[31:24], 8'h0e);
            // inv_mixColumn32[23:16] = lookupEL(block[7:0], 8'h0d) ^ lookupEL(block[15:8], 8'h0b) ^ lookupEL(block[23:16], 8'h0e) ^ lookupEL(block[31:24], 8'h09);
            // inv_mixColumn32[15: 8] = lookupEL(block[7:0], 8'h0b) ^ lookupEL(block[15:8], 8'h0e) ^ lookupEL(block[23:16], 8'h09) ^ lookupEL(block[31:24], 8'h0d);
            // inv_mixColumn32[ 7: 0] = lookupEL(block[7:0], 8'h0e) ^ lookupEL(block[15:8], 8'h09) ^ lookupEL(block[23:16], 8'h0d) ^ lookupEL(block[31:24], 8'h0b);

            inv_mixColumn32[31:24] = mul9(block[7:0]) ^ mul13(block[15:8]) ^ mul11(block[23:16]) ^ mul14(block[31:24]);
            inv_mixColumn32[23:16] = mul13(block[7:0]) ^ mul11(block[15:8]) ^ mul14(block[23:16]) ^ mul9(block[31:24]);
            inv_mixColumn32[15: 8] = mul11(block[7:0]) ^ mul14(block[15:8]) ^ mul9(block[23:16]) ^ mul13(block[31:24]);
            inv_mixColumn32[ 7: 0] = mul14(block[7:0]) ^ mul9(block[15:8]) ^ mul13(block[23:16]) ^ mul11(block[31:24]);

        end
    endfunction

    function [127:0] inv_mixColumn (input [127:0] block);
        begin
            inv_mixColumn[31:0] = inv_mixColumn32(block[31:0]);
            inv_mixColumn[63:32] = inv_mixColumn32(block[63:32]);
            inv_mixColumn[95:64] = inv_mixColumn32(block[95:64]);
            inv_mixColumn[127:96] = inv_mixColumn32(block[127:96]);
        end
    endfunction


    function [127:0] inv_shiftRow(input [127:0] block);
        begin
            inv_shiftRow[8*0+7:8*0] = block[8*12+7:8*12];
            inv_shiftRow[8*1+7:8*1] = block[8*9+7:8*9];
            inv_shiftRow[8*2+7:8*2] = block[8*6+7:8*6];
            inv_shiftRow[8*3+7:8*3] = block[8*3+7:8*3];

            inv_shiftRow[8*4+7:8*4] = block[8*0+7:8*0];
            inv_shiftRow[8*5+7:8*5] = block[8*13+7:8*13];
            inv_shiftRow[8*6+7:8*6] = block[8*10+7:8*10];
            inv_shiftRow[8*7+7:8*7] = block[8*7+7:8*7];

            inv_shiftRow[8*8+7:8*8] = block[8*4+7:8*4];
            inv_shiftRow[8*9+7:8*9] = block[8*1+7:8*1];
            inv_shiftRow[8*10+7:8*10] = block[8*14+7:8*14];
            inv_shiftRow[8*11+7:8*11] = block[8*11+7:8*11];

            inv_shiftRow[8*12+7:8*12] = block[8*8+7:8*8];
            inv_shiftRow[8*13+7:8*13] = block[8*5+7:8*5];
            inv_shiftRow[8*14+7:8*14] = block[8*2+7:8*2];
            inv_shiftRow[8*15+7:8*15] = block[8*15+7:8*15];
        end
    endfunction


    function [127:0] inv_subBytes (input [127:0] block);

        begin
            inv_subBytes[8*0+7:8*0] = inv_sbox[block[8*0+7:8*0]];
            inv_subBytes[8*1+7:8*1] = inv_sbox[block[8*1+7:8*1]];
            inv_subBytes[8*2+7:8*2] = inv_sbox[block[8*2+7:8*2]];
            inv_subBytes[8*3+7:8*3] = inv_sbox[block[8*3+7:8*3]];

            inv_subBytes[8*4+7:8*4] = inv_sbox[block[8*4+7:8*4]];
            inv_subBytes[8*5+7:8*5] = inv_sbox[block[8*5+7:8*5]];
            inv_subBytes[8*6+7:8*6] = inv_sbox[block[8*6+7:8*6]];
            inv_subBytes[8*7+7:8*7] = inv_sbox[block[8*7+7:8*7]];

            inv_subBytes[8*8+7:8*8] = inv_sbox[block[8*8+7:8*8]];
            inv_subBytes[8*9+7:8*9] = inv_sbox[block[8*9+7:8*9]];
            inv_subBytes[8*10+7:8*10] = inv_sbox[block[8*10+7:8*10]];
            inv_subBytes[8*11+7:8*11] = inv_sbox[block[8*11+7:8*11]];

            inv_subBytes[8*12+7:8*12] = inv_sbox[block[8*12+7:8*12]];
            inv_subBytes[8*13+7:8*13] = inv_sbox[block[8*13+7:8*13]];
            inv_subBytes[8*14+7:8*14] = inv_sbox[block[8*14+7:8*14]];
            inv_subBytes[8*15+7:8*15] = inv_sbox[block[8*15+7:8*15]];
        end
    endfunction


    function [127:0] addRoundKey (input [127:0] block, input [127:0] key);
        begin
            addRoundKey = block ^ key;
        end
    endfunction



    // ------------------------------------------------------
    // --------------------- reg update ---------------------
    // ------------------------------------------------------

    // flow:
    // 1. when reset, set ctrl_reg to 0
    // 2. when posedge clk, write reg_new into each reg
    // 3. these will trigger reg update and call the decipher_ctrl, etc.

    always @(posedge clk or negedge rst_n) begin : proc_ctrl_reg
        if(~rst_n) begin
            block_reg      <= 128'b0;
            main_ctrl_reg  <= CTRL_IDLE;
            round_ctrl_reg <= 4'b0;
            ready_reg      <= 1'b0;
        end else begin
            block_reg      <= block_new;
            main_ctrl_reg  <= main_ctrl_new;
            round_ctrl_reg <= round_ctrl_new;
            ready_reg      <= ready_new;
        end
    end


    // ------------------------------------------------------
    // ------------------ decipher control  -----------------
    // ------------------------------------------------------

    // flow:
    // 1. in the beginning, main_ctrl_reg should be IDLE
    // 2. goto case structure: IDLE
    //    if input "next" is true, start the decryption
    //    this will set the next state to INIT and reset the round controller to 0
    // 3. next clk goto case: INIT
    //    this will set update type to init and trigger round logic to do subByte, mixCol...
    //    also set round_inc to true so that the counter will start
    //    set next state to MAIN


    always @* begin : decipher_ctrl
        reg [3:0] num_rounds;

        // default assignments
        main_ctrl_new  = CTRL_IDLE;
        ready_new      = 1'b0;
        update_type    = NO_UPDATE;
        round_ctrl_dec = 1'b0;




        // main state machine
        case (main_ctrl_reg)
            CTRL_IDLE : begin
                if (next) begin
                    main_ctrl_new = CTRL_INIT;
                    update_type   = NO_UPDATE;
                end
            end
            CTRL_INIT : begin
                main_ctrl_new  = CTRL_MAIN;
                round_ctrl_dec = 1'b1;
                update_type    = INIT_UPDATE;
            end
            CTRL_MAIN : begin
                round_ctrl_dec = 1'b1;
                if (round_ctrl_reg > 0) begin
                    main_ctrl_new = CTRL_MAIN;
                    update_type   = MAIN_UPDATE;
                end else begin
                    main_ctrl_new = CTRL_IDLE;
                    update_type   = FINAL_UPDATE;
                    ready_new     = 1'b1;
                end
            end
            default : begin end
        endcase // ctrl_reg
    end // decipher_ctrl


    // ------------------------------------------------------
    // ------------------- round control --------------------
    // ------------------------------------------------------

    always @(*) begin : round_ctrl
        // default assignments
        if (keylen == AES_256_BIT_KEY) begin
            round_ctrl_new = AES256_ROUNDS;
        end else begin
            round_ctrl_new = AES128_ROUNDS;
        end

        if (round_ctrl_dec) begin
            round_ctrl_new = round_ctrl_reg - 1'b1;
        end
    end // round_ctrl


    // ------------------------------------------------------
    // -------------------- round logic ---------------------
    // ------------------------------------------------------

    always @(*) begin : round_logic

        // just for clear denotation
        reg [127:0] addRoundKey_block;
        reg [127:0] inv_subBytes_block, inv_shiftRow_block, inv_mixColumn_block;
        reg [127:0] init_addRoundKey_block, init_inv_shiftRow_block, init_inv_subBytes_block;

        addRoundKey_block   = addRoundKey(block_reg, round_key);
        inv_mixColumn_block = inv_mixColumn(addRoundKey_block);
        inv_shiftRow_block  = inv_shiftRow(inv_mixColumn_block);
        inv_subBytes_block  = inv_subBytes(inv_shiftRow_block);

        init_addRoundKey_block   = addRoundKey(block, round_key);
        init_inv_shiftRow_block = inv_shiftRow(init_addRoundKey_block);
        init_inv_subBytes_block = inv_subBytes(init_inv_shiftRow_block);

        // $display("in last round, block =   %h", block_reg);
        // $display("addRoundKey_block:       %h", addRoundKey_block);
        // $display("inv_mixColumn_block:     %h", inv_mixColumn_block);
        // $display("inv_shiftRow_block:      %h", inv_shiftRow_block);
        // $display("inv_subBytes_block:      %h", inv_subBytes_block);
        // $display("init_inv_shiftRow_block: %h", init_inv_shiftRow_block);
        // $display("init_inv_subBytes_block: %h\n", init_inv_subBytes_block);

        case (update_type)
            NO_UPDATE : begin
                block_new = block_reg;
            end
            INIT_UPDATE : begin
                block_new = init_inv_subBytes_block;
            end
            MAIN_UPDATE : begin
                block_new = inv_subBytes_block;
            end
            FINAL_UPDATE : begin
                block_new = addRoundKey_block;
            end
            default : begin end
        endcase // update_type
    end // round_logic


endmodule // AES_decipher

// module AES_decipher (
//     input clk,    // Clock
//     input clk_en, // Clock Enable
//     input rst_n,  // Asynchronous reset active low
    
// );

// endmodule