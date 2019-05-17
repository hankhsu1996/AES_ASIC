// for higher level module, constant.v may be double included
// uncomment to run testbench
// `include "constant.v"
`timescale 1ns/1ps

module AES_encipher (
    input          clk      , // Clock
    input          rst_n    , // Asynchronous reset active low
    input          next     , // Use next to indicate the next request for encipher
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


    // the register to store control state information
    reg [2:0] main_ctrl_reg;
    reg [2:0] main_ctrl_new;
    reg       ready_reg    ;
    reg       ready_new    ;

    // reg to save round controller information
    reg [3:0] round_ctrl_reg;
    reg [3:0] round_ctrl_new;
    reg       round_ctrl_inc;

    // the register to indicate what kind of round (init, main and final)
    reg [  1:0] update_type;
    reg [127:0] block_reg  ;
    reg [127:0] block_new  ;

    // Concurrent connectivity for ports
    assign ready     = ready_reg;
    assign round     = round_ctrl_reg;
    assign new_block = block_reg;

    wire [7:0] sbox[255:0];

    assign sbox[8'h00] = 8'h63;
    assign sbox[8'h01] = 8'h7c;
    assign sbox[8'h02] = 8'h77;
    assign sbox[8'h03] = 8'h7b;
    assign sbox[8'h04] = 8'hf2;
    assign sbox[8'h05] = 8'h6b;
    assign sbox[8'h06] = 8'h6f;
    assign sbox[8'h07] = 8'hc5;
    assign sbox[8'h08] = 8'h30;
    assign sbox[8'h09] = 8'h01;
    assign sbox[8'h0a] = 8'h67;
    assign sbox[8'h0b] = 8'h2b;
    assign sbox[8'h0c] = 8'hfe;
    assign sbox[8'h0d] = 8'hd7;
    assign sbox[8'h0e] = 8'hab;
    assign sbox[8'h0f] = 8'h76;
    assign sbox[8'h10] = 8'hca;
    assign sbox[8'h11] = 8'h82;
    assign sbox[8'h12] = 8'hc9;
    assign sbox[8'h13] = 8'h7d;
    assign sbox[8'h14] = 8'hfa;
    assign sbox[8'h15] = 8'h59;
    assign sbox[8'h16] = 8'h47;
    assign sbox[8'h17] = 8'hf0;
    assign sbox[8'h18] = 8'had;
    assign sbox[8'h19] = 8'hd4;
    assign sbox[8'h1a] = 8'ha2;
    assign sbox[8'h1b] = 8'haf;
    assign sbox[8'h1c] = 8'h9c;
    assign sbox[8'h1d] = 8'ha4;
    assign sbox[8'h1e] = 8'h72;
    assign sbox[8'h1f] = 8'hc0;
    assign sbox[8'h20] = 8'hb7;
    assign sbox[8'h21] = 8'hfd;
    assign sbox[8'h22] = 8'h93;
    assign sbox[8'h23] = 8'h26;
    assign sbox[8'h24] = 8'h36;
    assign sbox[8'h25] = 8'h3f;
    assign sbox[8'h26] = 8'hf7;
    assign sbox[8'h27] = 8'hcc;
    assign sbox[8'h28] = 8'h34;
    assign sbox[8'h29] = 8'ha5;
    assign sbox[8'h2a] = 8'he5;
    assign sbox[8'h2b] = 8'hf1;
    assign sbox[8'h2c] = 8'h71;
    assign sbox[8'h2d] = 8'hd8;
    assign sbox[8'h2e] = 8'h31;
    assign sbox[8'h2f] = 8'h15;
    assign sbox[8'h30] = 8'h04;
    assign sbox[8'h31] = 8'hc7;
    assign sbox[8'h32] = 8'h23;
    assign sbox[8'h33] = 8'hc3;
    assign sbox[8'h34] = 8'h18;
    assign sbox[8'h35] = 8'h96;
    assign sbox[8'h36] = 8'h05;
    assign sbox[8'h37] = 8'h9a;
    assign sbox[8'h38] = 8'h07;
    assign sbox[8'h39] = 8'h12;
    assign sbox[8'h3a] = 8'h80;
    assign sbox[8'h3b] = 8'he2;
    assign sbox[8'h3c] = 8'heb;
    assign sbox[8'h3d] = 8'h27;
    assign sbox[8'h3e] = 8'hb2;
    assign sbox[8'h3f] = 8'h75;
    assign sbox[8'h40] = 8'h09;
    assign sbox[8'h41] = 8'h83;
    assign sbox[8'h42] = 8'h2c;
    assign sbox[8'h43] = 8'h1a;
    assign sbox[8'h44] = 8'h1b;
    assign sbox[8'h45] = 8'h6e;
    assign sbox[8'h46] = 8'h5a;
    assign sbox[8'h47] = 8'ha0;
    assign sbox[8'h48] = 8'h52;
    assign sbox[8'h49] = 8'h3b;
    assign sbox[8'h4a] = 8'hd6;
    assign sbox[8'h4b] = 8'hb3;
    assign sbox[8'h4c] = 8'h29;
    assign sbox[8'h4d] = 8'he3;
    assign sbox[8'h4e] = 8'h2f;
    assign sbox[8'h4f] = 8'h84;
    assign sbox[8'h50] = 8'h53;
    assign sbox[8'h51] = 8'hd1;
    assign sbox[8'h52] = 8'h00;
    assign sbox[8'h53] = 8'hed;
    assign sbox[8'h54] = 8'h20;
    assign sbox[8'h55] = 8'hfc;
    assign sbox[8'h56] = 8'hb1;
    assign sbox[8'h57] = 8'h5b;
    assign sbox[8'h58] = 8'h6a;
    assign sbox[8'h59] = 8'hcb;
    assign sbox[8'h5a] = 8'hbe;
    assign sbox[8'h5b] = 8'h39;
    assign sbox[8'h5c] = 8'h4a;
    assign sbox[8'h5d] = 8'h4c;
    assign sbox[8'h5e] = 8'h58;
    assign sbox[8'h5f] = 8'hcf;
    assign sbox[8'h60] = 8'hd0;
    assign sbox[8'h61] = 8'hef;
    assign sbox[8'h62] = 8'haa;
    assign sbox[8'h63] = 8'hfb;
    assign sbox[8'h64] = 8'h43;
    assign sbox[8'h65] = 8'h4d;
    assign sbox[8'h66] = 8'h33;
    assign sbox[8'h67] = 8'h85;
    assign sbox[8'h68] = 8'h45;
    assign sbox[8'h69] = 8'hf9;
    assign sbox[8'h6a] = 8'h02;
    assign sbox[8'h6b] = 8'h7f;
    assign sbox[8'h6c] = 8'h50;
    assign sbox[8'h6d] = 8'h3c;
    assign sbox[8'h6e] = 8'h9f;
    assign sbox[8'h6f] = 8'ha8;
    assign sbox[8'h70] = 8'h51;
    assign sbox[8'h71] = 8'ha3;
    assign sbox[8'h72] = 8'h40;
    assign sbox[8'h73] = 8'h8f;
    assign sbox[8'h74] = 8'h92;
    assign sbox[8'h75] = 8'h9d;
    assign sbox[8'h76] = 8'h38;
    assign sbox[8'h77] = 8'hf5;
    assign sbox[8'h78] = 8'hbc;
    assign sbox[8'h79] = 8'hb6;
    assign sbox[8'h7a] = 8'hda;
    assign sbox[8'h7b] = 8'h21;
    assign sbox[8'h7c] = 8'h10;
    assign sbox[8'h7d] = 8'hff;
    assign sbox[8'h7e] = 8'hf3;
    assign sbox[8'h7f] = 8'hd2;
    assign sbox[8'h80] = 8'hcd;
    assign sbox[8'h81] = 8'h0c;
    assign sbox[8'h82] = 8'h13;
    assign sbox[8'h83] = 8'hec;
    assign sbox[8'h84] = 8'h5f;
    assign sbox[8'h85] = 8'h97;
    assign sbox[8'h86] = 8'h44;
    assign sbox[8'h87] = 8'h17;
    assign sbox[8'h88] = 8'hc4;
    assign sbox[8'h89] = 8'ha7;
    assign sbox[8'h8a] = 8'h7e;
    assign sbox[8'h8b] = 8'h3d;
    assign sbox[8'h8c] = 8'h64;
    assign sbox[8'h8d] = 8'h5d;
    assign sbox[8'h8e] = 8'h19;
    assign sbox[8'h8f] = 8'h73;
    assign sbox[8'h90] = 8'h60;
    assign sbox[8'h91] = 8'h81;
    assign sbox[8'h92] = 8'h4f;
    assign sbox[8'h93] = 8'hdc;
    assign sbox[8'h94] = 8'h22;
    assign sbox[8'h95] = 8'h2a;
    assign sbox[8'h96] = 8'h90;
    assign sbox[8'h97] = 8'h88;
    assign sbox[8'h98] = 8'h46;
    assign sbox[8'h99] = 8'hee;
    assign sbox[8'h9a] = 8'hb8;
    assign sbox[8'h9b] = 8'h14;
    assign sbox[8'h9c] = 8'hde;
    assign sbox[8'h9d] = 8'h5e;
    assign sbox[8'h9e] = 8'h0b;
    assign sbox[8'h9f] = 8'hdb;
    assign sbox[8'ha0] = 8'he0;
    assign sbox[8'ha1] = 8'h32;
    assign sbox[8'ha2] = 8'h3a;
    assign sbox[8'ha3] = 8'h0a;
    assign sbox[8'ha4] = 8'h49;
    assign sbox[8'ha5] = 8'h06;
    assign sbox[8'ha6] = 8'h24;
    assign sbox[8'ha7] = 8'h5c;
    assign sbox[8'ha8] = 8'hc2;
    assign sbox[8'ha9] = 8'hd3;
    assign sbox[8'haa] = 8'hac;
    assign sbox[8'hab] = 8'h62;
    assign sbox[8'hac] = 8'h91;
    assign sbox[8'had] = 8'h95;
    assign sbox[8'hae] = 8'he4;
    assign sbox[8'haf] = 8'h79;
    assign sbox[8'hb0] = 8'he7;
    assign sbox[8'hb1] = 8'hc8;
    assign sbox[8'hb2] = 8'h37;
    assign sbox[8'hb3] = 8'h6d;
    assign sbox[8'hb4] = 8'h8d;
    assign sbox[8'hb5] = 8'hd5;
    assign sbox[8'hb6] = 8'h4e;
    assign sbox[8'hb7] = 8'ha9;
    assign sbox[8'hb8] = 8'h6c;
    assign sbox[8'hb9] = 8'h56;
    assign sbox[8'hba] = 8'hf4;
    assign sbox[8'hbb] = 8'hea;
    assign sbox[8'hbc] = 8'h65;
    assign sbox[8'hbd] = 8'h7a;
    assign sbox[8'hbe] = 8'hae;
    assign sbox[8'hbf] = 8'h08;
    assign sbox[8'hc0] = 8'hba;
    assign sbox[8'hc1] = 8'h78;
    assign sbox[8'hc2] = 8'h25;
    assign sbox[8'hc3] = 8'h2e;
    assign sbox[8'hc4] = 8'h1c;
    assign sbox[8'hc5] = 8'ha6;
    assign sbox[8'hc6] = 8'hb4;
    assign sbox[8'hc7] = 8'hc6;
    assign sbox[8'hc8] = 8'he8;
    assign sbox[8'hc9] = 8'hdd;
    assign sbox[8'hca] = 8'h74;
    assign sbox[8'hcb] = 8'h1f;
    assign sbox[8'hcc] = 8'h4b;
    assign sbox[8'hcd] = 8'hbd;
    assign sbox[8'hce] = 8'h8b;
    assign sbox[8'hcf] = 8'h8a;
    assign sbox[8'hd0] = 8'h70;
    assign sbox[8'hd1] = 8'h3e;
    assign sbox[8'hd2] = 8'hb5;
    assign sbox[8'hd3] = 8'h66;
    assign sbox[8'hd4] = 8'h48;
    assign sbox[8'hd5] = 8'h03;
    assign sbox[8'hd6] = 8'hf6;
    assign sbox[8'hd7] = 8'h0e;
    assign sbox[8'hd8] = 8'h61;
    assign sbox[8'hd9] = 8'h35;
    assign sbox[8'hda] = 8'h57;
    assign sbox[8'hdb] = 8'hb9;
    assign sbox[8'hdc] = 8'h86;
    assign sbox[8'hdd] = 8'hc1;
    assign sbox[8'hde] = 8'h1d;
    assign sbox[8'hdf] = 8'h9e;
    assign sbox[8'he0] = 8'he1;
    assign sbox[8'he1] = 8'hf8;
    assign sbox[8'he2] = 8'h98;
    assign sbox[8'he3] = 8'h11;
    assign sbox[8'he4] = 8'h69;
    assign sbox[8'he5] = 8'hd9;
    assign sbox[8'he6] = 8'h8e;
    assign sbox[8'he7] = 8'h94;
    assign sbox[8'he8] = 8'h9b;
    assign sbox[8'he9] = 8'h1e;
    assign sbox[8'hea] = 8'h87;
    assign sbox[8'heb] = 8'he9;
    assign sbox[8'hec] = 8'hce;
    assign sbox[8'hed] = 8'h55;
    assign sbox[8'hee] = 8'h28;
    assign sbox[8'hef] = 8'hdf;
    assign sbox[8'hf0] = 8'h8c;
    assign sbox[8'hf1] = 8'ha1;
    assign sbox[8'hf2] = 8'h89;
    assign sbox[8'hf3] = 8'h0d;
    assign sbox[8'hf4] = 8'hbf;
    assign sbox[8'hf5] = 8'he6;
    assign sbox[8'hf6] = 8'h42;
    assign sbox[8'hf7] = 8'h68;
    assign sbox[8'hf8] = 8'h41;
    assign sbox[8'hf9] = 8'h99;
    assign sbox[8'hfa] = 8'h2d;
    assign sbox[8'hfb] = 8'h0f;
    assign sbox[8'hfc] = 8'hb0;
    assign sbox[8'hfd] = 8'h54;
    assign sbox[8'hfe] = 8'hbb;
    assign sbox[8'hff] = 8'h16;

    // ------------------------------------------------------
    // ---------------- basic four functions ----------------
    // ------------------------------------------------------

    function [7:0] mixColumn32;
        input [7:0] i1,i2,i3,i4;
        begin
            mixColumn32[7]=i1[6]^i2[6]^i2[7]^i3[7]^i4[7];
            mixColumn32[6]=i1[5]^i2[5]^i2[6]^i3[6]^i4[6];
            mixColumn32[5]=i1[4]^i2[4]^i2[5]^i3[5]^i4[5];
            mixColumn32[4]=i1[3]^i1[7]^i2[3]^i2[4]^i2[7]^i3[4]^i4[4];
            mixColumn32[3]=i1[2]^i1[7]^i2[2]^i2[3]^i2[7]^i3[3]^i4[3];
            mixColumn32[2]=i1[1]^i2[1]^i2[2]^i3[2]^i4[2];
            mixColumn32[1]=i1[0]^i1[7]^i2[0]^i2[1]^i2[7]^i3[1]^i4[1];
            mixColumn32[0]=i1[7]^i2[7]^i2[0]^i3[0]^i4[0];
        end
    endfunction


    function [127:0] mixColumn (input [127:0] block);
        begin
            mixColumn[127:120] = mixColumn32 (block[127:120],block[119:112],block[111:104],block[103:96]);
            mixColumn[119:112] = mixColumn32 (block[119:112],block[111:104],block[103:96],block[127:120]);
            mixColumn[111:104] = mixColumn32 (block[111:104],block[103:96],block[127:120],block[119:112]);
            mixColumn[103:96]  = mixColumn32 (block[103:96],block[127:120],block[119:112],block[111:104]);
            mixColumn[95:88]   = mixColumn32 (block[95:88],block[87:80],block[79:72],block[71:64]);
            mixColumn[87:80]   = mixColumn32 (block[87:80],block[79:72],block[71:64],block[95:88]);
            mixColumn[79:72]   = mixColumn32 (block[79:72],block[71:64],block[95:88],block[87:80]);
            mixColumn[71:64]   = mixColumn32 (block[71:64],block[95:88],block[87:80],block[79:72]);
            mixColumn[63:56]   = mixColumn32 (block[63:56],block[55:48],block[47:40],block[39:32]);
            mixColumn[55:48]   = mixColumn32 (block[55:48],block[47:40],block[39:32],block[63:56]);
            mixColumn[47:40]   = mixColumn32 (block[47:40],block[39:32],block[63:56],block[55:48]);
            mixColumn[39:32]   = mixColumn32 (block[39:32],block[63:56],block[55:48],block[47:40]);
            mixColumn[31:24]   = mixColumn32 (block[31:24],block[23:16],block[15:8],block[7:0]);
            mixColumn[23:16]   = mixColumn32 (block[23:16],block[15:8],block[7:0],block[31:24]);
            mixColumn[15:8]    = mixColumn32 (block[15:8],block[7:0],block[31:24],block[23:16]);
            mixColumn[7:0]     = mixColumn32 (block[7:0],block[31:24],block[23:16],block[15:8]);
            // $display("---- mixCols:  %h ----", mixColumn);
        end
    endfunction


    function [127:0] shiftRow(input [127:0] block);
        begin
            shiftRow[8*0+7:8*0] = block[8*4+7:8*4];
            shiftRow[8*1+7:8*1] = block[8*9+7:8*9];
            shiftRow[8*2+7:8*2] = block[8*14+7:8*14];
            shiftRow[8*3+7:8*3] = block[8*3+7:8*3];

            shiftRow[8*4+7:8*4] = block[8*8+7:8*8];
            shiftRow[8*5+7:8*5] = block[8*13+7:8*13];
            shiftRow[8*6+7:8*6] = block[8*2+7:8*2];
            shiftRow[8*7+7:8*7] = block[8*7+7:8*7];

            shiftRow[8*8+7:8*8] = block[8*12+7:8*12];
            shiftRow[8*9+7:8*9] = block[8*1+7:8*1];
            shiftRow[8*10+7:8*10] = block[8*6+7:8*6];
            shiftRow[8*11+7:8*11] = block[8*11+7:8*11];

            shiftRow[8*12+7:8*12] = block[8*0+7:8*0];
            shiftRow[8*13+7:8*13] = block[8*5+7:8*5];
            shiftRow[8*14+7:8*14] = block[8*10+7:8*10];
            shiftRow[8*15+7:8*15] = block[8*15+7:8*15];
            // $display("---- shiftRow: %h ----", shiftRow);
        end
    endfunction


    function [127:0] subBytes (input [127:0] block);
        begin


            subBytes[8*0+7:8*0] = sbox[block[8*0+7:8*0]];
            subBytes[8*1+7:8*1] = sbox[block[8*1+7:8*1]];
            subBytes[8*2+7:8*2] = sbox[block[8*2+7:8*2]];
            subBytes[8*3+7:8*3] = sbox[block[8*3+7:8*3]];

            subBytes[8*4+7:8*4] = sbox[block[8*4+7:8*4]];
            subBytes[8*5+7:8*5] = sbox[block[8*5+7:8*5]];
            subBytes[8*6+7:8*6] = sbox[block[8*6+7:8*6]];
            subBytes[8*7+7:8*7] = sbox[block[8*7+7:8*7]];

            subBytes[8*8+7:8*8] = sbox[block[8*8+7:8*8]];
            subBytes[8*9+7:8*9] = sbox[block[8*9+7:8*9]];
            subBytes[8*10+7:8*10] = sbox[block[8*10+7:8*10]];
            subBytes[8*11+7:8*11] = sbox[block[8*11+7:8*11]];

            subBytes[8*12+7:8*12] = sbox[block[8*12+7:8*12]];
            subBytes[8*13+7:8*13] = sbox[block[8*13+7:8*13]];
            subBytes[8*14+7:8*14] = sbox[block[8*14+7:8*14]];
            subBytes[8*15+7:8*15] = sbox[block[8*15+7:8*15]];
            // $display("---- subBytes: %h ----", subBytes);
        end
    endfunction


    function [127:0] addRoundKey (input [127:0] block, input [127:0] key);
        begin
            addRoundKey = block ^ key;
            // $display("---- addKey  : %h ----", addRoundKey);
        end
    endfunction



    // ------------------------------------------------------
    // --------------------- reg update ---------------------
    // ------------------------------------------------------

    // flow:
    // 1. when reset, set ctrl_reg to 0
    // 2. when posedge clk, write reg_new into each reg
    // 3. these will trigger reg update and call the encipher_ctrl, etc.

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
    // ------------------ encipher control  -----------------
    // ------------------------------------------------------

    // flow:
    // 1. in the beginning, main_ctrl_reg should be IDLE
    // 2. goto case structure: IDLE
    //    if input "next" is true, start the encryption
    //    this will set the next state to INIT and reset the round controller to 0
    // 3. next clk goto case: INIT
    //    this will set update type to init and trigger round logic to do subByte, mixCol...
    //    also set round_inc to true so that the counter will start
    //    set next state to MAIN


    always @* begin : encipher_ctrl
        reg [3:0] num_rounds;

        // default assignments
        main_ctrl_new  = CTRL_IDLE;
        ready_new      = 1'b0;
        update_type    = NO_UPDATE;
        round_ctrl_inc = 1'b0;

        // get num_rounds
        if (keylen == AES_256_BIT_KEY) begin
            num_rounds = AES256_ROUNDS;
        end else begin
            num_rounds = AES128_ROUNDS;
        end


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
                round_ctrl_inc = 1'b1;
                update_type    = INIT_UPDATE;
            end
            CTRL_MAIN : begin
                round_ctrl_inc = 1'b1;
                if (round_ctrl_reg < num_rounds) begin
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
    end // encipher_ctrl


    // ------------------------------------------------------
    // ------------------- round control --------------------
    // ------------------------------------------------------

    always @(*) begin : round_ctrl
        // default assignments
        round_ctrl_new = 4'h0;
        if (round_ctrl_inc) begin
            round_ctrl_new = round_ctrl_reg + 1'b1;
        end
    end // round_ctrl


    // ------------------------------------------------------
    // -------------------- round logic ---------------------
    // ------------------------------------------------------

    always @(*) begin : round_logic

        // just for clear denotation
        reg [127:0] subBytes_block, shiftRow_block, mixColumn_block;
        reg [127:0] addRoundKey_block, init_addRoundKey_block, final_addRoundKey_block;

        subBytes_block          = subBytes(block_reg);
        shiftRow_block          = shiftRow(subBytes_block);
        mixColumn_block         = mixColumn(shiftRow_block);
        addRoundKey_block       = addRoundKey(mixColumn_block, round_key);
        init_addRoundKey_block  = addRoundKey(block, round_key);
        final_addRoundKey_block = addRoundKey(shiftRow_block, round_key);

        // $display("in last round, block =   %h", block_reg);
        // $display("subBytes_block:          %h", subBytes_block);
        // $display("shiftRow_block:          %h", shiftRow_block);
        // $display("mixColumn_block:         %h", mixColumn_block);
        // $display("addRoundKey_block:       %h", addRoundKey_block);
        // $display("init_addRoundKey_block:  %h", init_addRoundKey_block);
        // $display("final_addRoundKey_block: %h\n", final_addRoundKey_block);

        case (update_type)
            NO_UPDATE : begin
                block_new = block_reg;
            end
            INIT_UPDATE : begin
                block_new = init_addRoundKey_block;
            end
            MAIN_UPDATE : begin
                block_new = addRoundKey_block;
            end
            FINAL_UPDATE : begin
                block_new = final_addRoundKey_block;
            end
            default : begin end
        endcase // update_type
    end // round_logic


endmodule // AES_encipher