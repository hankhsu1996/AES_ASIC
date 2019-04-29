`include "constant.v"
`timescale 1ns/1ps

module AES_encipher (
    input          clk      , // Clock
    input          rst_n    , // Asynchronous reset active low
    input          next     , // Use next to indicate the next request for encipher
    input          keylen   , // Use keylen to indicate AES128 or AES256, not yet implemented
    output         round    , // Use round to request the round key
    input  [127:0] round_key,
    input  [127:0] block    ,
    output [127:0] new_block,
    output         ready
);

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
        end
    endfunction


    function [127:0] subBytes (input [127:0] block);
        begin
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


    // define control state
    localparam CTRL_IDLE  = 3'h0;
    localparam CTRL_INIT  = 3'h1;
    localparam CTRL_MAIN  = 3'h2;
    localparam CTRL_FINAL = 3'h3;

    localparam AES_128_BIT_KEY = 1'h0;
    localparam AES_256_BIT_KEY = 1'h1;

    localparam AES128_ROUNDS = 4'ha;
    localparam AES256_ROUNDS = 4'he;

    // the register to store state information
    reg [2:0] main_ctrl_reg;
    reg [2:0] main_ctrl_new;
    reg       ready_reg    ;
    reg       ready_new    ;


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

    // reg to save round controller information
    reg [3:0] round_ctrl_reg;
    reg [3:0] round_ctrl_new;
    reg       round_ctrl_inc;

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

    // define update type
    localparam NO_UPDATE    = 3'h0;
    localparam INIT_UPDATE  = 3'h1;
    localparam MAIN_UPDATE  = 3'h2;
    localparam FINAL_UPDATE = 3'h3;

    // the register to indicate what kind of round (init, main and final)
    reg         update_type;
    reg [127:0] block_reg  ;
    reg [127:0] block_new  ;

    always @(*) begin : round_logic

        // just for clear denotation
        reg [127:0] shiftRow_block, mixColumn_block;
        reg [127:0] addRoundKey_block, init_addRoundKey_block, final_addRoundKey_block;

        shiftRow_block          = shiftRow(block_reg);
        mixColumn_block         = mixColumn(shiftRow_block);
        addRoundKey_block       = addRoundKey(mixColumn_block, round_key);
        init_addRoundKey_block  = addRoundKey(block, round_key);
        final_addRoundKey_block = addRoundKey(shiftRow_block, round_key);

        case (update_type)
            NO_UPDATE   : begin end
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