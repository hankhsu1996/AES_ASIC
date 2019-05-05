`include "constant.v"
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

    // ------------------------------------------------------
    // ---------------- basic four functions ----------------
    // ------------------------------------------------------

    function [7:0] lookupE (input [7:0] block);
        lookupE = constant.E[block];
    endfunction

    function [7:0] lookupL (input [7:0] block);
        lookupL = constant.L[block];
    endfunction

    function [7:0] add(input [7:0] a, input [7:0] b);
        reg [8:0] temp;
        begin
            temp = a + b;

            if (temp > 8'hff) begin
                temp = temp - 8'hff;
            end

            add[7:0] = temp[7:0];
        end
    endfunction

    function [7:0] lookupEL(input [7:0] block, input [7:0] constant);
        if (block == 8'h00) begin
            lookupEL = 8'h00;
        end else begin
            lookupEL = lookupE(add(lookupL(block), lookupL(constant)));
        end
    endfunction

    function [31:0] inv_mixColumn32(input [31:0] block);
        begin
            inv_mixColumn32[31:24] = lookupEL(block[7:0], 8'h09) ^ lookupEL(block[15:8], 8'h0d) ^ lookupEL(block[23:16], 8'h0b) ^ lookupEL(block[31:24], 8'h0e);
            inv_mixColumn32[23:16] = lookupEL(block[7:0], 8'h0d) ^ lookupEL(block[15:8], 8'h0b) ^ lookupEL(block[23:16], 8'h0e) ^ lookupEL(block[31:24], 8'h09);
            inv_mixColumn32[15: 8] = lookupEL(block[7:0], 8'h0b) ^ lookupEL(block[15:8], 8'h0e) ^ lookupEL(block[23:16], 8'h09) ^ lookupEL(block[31:24], 8'h0d);
            inv_mixColumn32[ 7: 0] = lookupEL(block[7:0], 8'h0e) ^ lookupEL(block[15:8], 8'h09) ^ lookupEL(block[23:16], 8'h0d) ^ lookupEL(block[31:24], 8'h0b);

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
            shiftRow[8*0+7:8*0] = block[8*12+7:8*12];
            shiftRow[8*1+7:8*1] = block[8*9+7:8*9];
            shiftRow[8*2+7:8*2] = block[8*6+7:8*6];
            shiftRow[8*3+7:8*3] = block[8*3+7:8*3];

            shiftRow[8*4+7:8*4] = block[8*0+7:8*0];
            shiftRow[8*5+7:8*5] = block[8*13+7:8*13];
            shiftRow[8*6+7:8*6] = block[8*10+7:8*10];
            shiftRow[8*7+7:8*7] = block[8*7+7:8*7];

            shiftRow[8*8+7:8*8] = block[8*4+7:8*4];
            shiftRow[8*9+7:8*9] = block[8*1+7:8*1];
            shiftRow[8*10+7:8*10] = block[8*14+7:8*14];
            shiftRow[8*11+7:8*11] = block[8*11+7:8*11];

            shiftRow[8*12+7:8*12] = block[8*8+7:8*8];
            shiftRow[8*13+7:8*13] = block[8*5+7:8*5];
            shiftRow[8*14+7:8*14] = block[8*2+7:8*2];
            shiftRow[8*15+7:8*15] = block[8*15+7:8*15];
        end
    endfunction


    function [127:0] inv_subBytes (input [127:0] block);
        begin
            subBytes[8*0+7:8*0] = constant.inv_sbox[block[8*0+7:8*0]];
            subBytes[8*1+7:8*1] = constant.inv_sbox[block[8*1+7:8*1]];
            subBytes[8*2+7:8*2] = constant.inv_sbox[block[8*2+7:8*2]];
            subBytes[8*3+7:8*3] = constant.inv_sbox[block[8*3+7:8*3]];

            subBytes[8*4+7:8*4] = constant.inv_sbox[block[8*4+7:8*4]];
            subBytes[8*5+7:8*5] = constant.inv_sbox[block[8*5+7:8*5]];
            subBytes[8*6+7:8*6] = constant.inv_sbox[block[8*6+7:8*6]];
            subBytes[8*7+7:8*7] = constant.inv_sbox[block[8*7+7:8*7]];

            subBytes[8*8+7:8*8] = constant.inv_sbox[block[8*8+7:8*8]];
            subBytes[8*9+7:8*9] = constant.inv_sbox[block[8*9+7:8*9]];
            subBytes[8*10+7:8*10] = constant.inv_sbox[block[8*10+7:8*10]];
            subBytes[8*11+7:8*11] = constant.inv_sbox[block[8*11+7:8*11]];

            subBytes[8*12+7:8*12] = constant.inv_sbox[block[8*12+7:8*12]];
            subBytes[8*13+7:8*13] = constant.inv_sbox[block[8*13+7:8*13]];
            subBytes[8*14+7:8*14] = constant.inv_sbox[block[8*14+7:8*14]];
            subBytes[8*15+7:8*15] = constant.inv_sbox[block[8*15+7:8*15]];
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
    end // decipher_ctrl


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

        subBytes_block          = inv_subBytes(block_reg);
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


endmodule // AES_decipher