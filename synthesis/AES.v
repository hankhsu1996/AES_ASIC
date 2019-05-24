module AES (
    input         clk     , // Clock
    input         rst_n   , // Asynchronous reset active low
    input  [ 3:0] address , // 4 bits address
    input  [15:0] data_in , // 16 bits input
    output [ 7:0] data_out  // 8 bits output, totally 30 pins
);

    // I modified:
    // 1. Convert to SystemVerilog 2009 syntax
    // 2. control => address
    // 3. Remove write enable, since I cannot understand why there is write enable reg.
    //    If  write enable is needed, we have to add another input
    // 4. rename parameters

    // -------------------------------------------------------------------------------------//
    // -------------------------------- address definition ---------------------------------//
    // -------------------------------------------------------------------------------------//

    localparam ADDR_IDLE = 4'h0;

    localparam ADDR_CONFIG       = 4'h1;
    localparam CONFIG_ENCDEC_BIT = 0   ; // 0: dec, 1: enc
    localparam CONFIG_KEYLEN_BIT = 1   ; // 0: 128, 1: 256

    localparam ADDR_KEY = 4'h2;

    localparam ADDR_BLOCK = 4'h3;

    localparam ADDR_STATUS      = 4'h5;
    localparam STATUS_READY_BIT = 0   ;
    localparam STATUS_VALID_BIT = 1   ;

    localparam ADDR_START     = 4'h6;
    localparam START_INIT_BIT = 0   ;
    localparam START_NEXT_BIT = 1   ;

    localparam ADDR_RESULT = 4'h7;

    // -------------------------------------------------------------------------------------//
    // ------------------------------- finite state machine --------------------------------//
    // -------------------------------------------------------------------------------------//

    localparam CTRL_IDLE      = 4'h0;
    localparam CTRL_CONFIG    = 4'h1;
    localparam CTRL_KEY       = 4'h2;
    localparam CTRL_BLOCK     = 4'h3;
    localparam CTRL_READING   = 4'h4;
    localparam CTRL_STATUS    = 4'h5;
    localparam CTRL_START     = 4'h6;
    localparam CTRL_OUTPUTING = 4'h7;

    localparam AES_128_BIT_KEY = 1'h0;
    localparam AES_256_BIT_KEY = 1'h1;

    localparam KEY128_ROUNDS = 4'h8;
    localparam KEY256_ROUNDS = 4'hf;
    localparam BLOCK_ROUNDS  = 4'h8;
    localparam OUTPUT_ROUNDS = 4'hf;


    // -------------------------------------------------------------------------------------//
    // ---------------------------------- register & wire ----------------------------------//
    // -------------------------------------------------------------------------------------//

    // for AES core
    reg  encdec_reg ; // save encdec
    wire core_encdec;

    reg  init_reg ; // start generating keys
    reg  init_new ;
    wire core_init;

    reg  next_reg ; // start encipher/decipher
    reg  next_new ;
    wire core_next;

    reg  ready_reg ;
    wire core_ready;

    reg  [ 15:0] key_reg    [0:15]; // receive 16 bits everytime
    wire [255:0] core_key         ;
    reg          keylen_reg       ;
    wire         core_keylen      ;

    reg  [ 15:0] block_reg [0:7]; // receive 16 bits everytime
    wire [127:0] core_block     ;

    reg  [127:0] result_reg       ;
    wire [127:0] core_result      ;
    wire [  7:0] result_tmp [15:0];
    reg          valid_reg        ;
    wire         core_valid       ;

    // according to current state, output corresponding data
    reg [7:0] tmp_data_out;

    // for state machine counter
    reg [3:0] main_ctrl_reg;
    reg [3:0] main_ctrl_new;
    reg [3:0] counter_reg  ;
    reg [3:0] counter_new  ;
    reg       counter_inc  ;

    integer i;


    // -------------------------------------------------------------------------------------------//
    // ---------------------------------------- assignment ---------------------------------------//
    // -------------------------------------------------------------------------------------------//

    assign core_encdec = encdec_reg;
    assign core_init   = init_reg;
    assign core_next   = next_reg;
    assign core_key    = {
        key_reg[0], key_reg[1], key_reg[2], key_reg[3],
        key_reg[4], key_reg[5], key_reg[6], key_reg[7],
        key_reg[8], key_reg[9], key_reg[10], key_reg[11],
        key_reg[12], key_reg[13], key_reg[14], key_reg[15]
    };
    assign core_keylen = keylen_reg;
    assign core_block  = {
        block_reg[0], block_reg[1], block_reg[2], block_reg[3],
        block_reg[4], block_reg[5], block_reg[6], block_reg[7]
    };
    assign result_tmp[0]  = result_reg[127-8*0:120-8*0];
    assign result_tmp[1]  = result_reg[127-8*1:120-8*1];
    assign result_tmp[2]  = result_reg[127-8*2:120-8*2];
    assign result_tmp[3]  = result_reg[127-8*3:120-8*3];
    assign result_tmp[4]  = result_reg[127-8*4:120-8*4];
    assign result_tmp[5]  = result_reg[127-8*5:120-8*5];
    assign result_tmp[6]  = result_reg[127-8*6:120-8*6];
    assign result_tmp[7]  = result_reg[127-8*7:120-8*7];
    assign result_tmp[8]  = result_reg[127-8*8:120-8*8];
    assign result_tmp[9]  = result_reg[127-8*9:120-8*9];
    assign result_tmp[10] = result_reg[127-8*10:120-8*10];
    assign result_tmp[11] = result_reg[127-8*11:120-8*11];
    assign result_tmp[12] = result_reg[127-8*12:120-8*12];
    assign result_tmp[13] = result_reg[127-8*13:120-8*13];
    assign result_tmp[14] = result_reg[127-8*14:120-8*14];
    assign result_tmp[15] = result_reg[127-8*15:120-8*15];

    assign data_out = tmp_data_out;

    // -------------------------------------------------------------------------------------------//
    // ------------------------------------ core instantiation -----------------------------------//
    // -------------------------------------------------------------------------------------------//

    AES_core core (
        .clk         (clk        ),
        .rst_n       (rst_n      ),
        .encdec      (core_encdec),
        .init        (core_init  ),
        .next        (core_next  ),
        .ready       (core_ready ),
        .key         (core_key   ),
        .keylen      (core_keylen),
        .block       (core_block ),
        .result      (core_result),
        .result_valid(core_valid )
    );

    // -------------------------------------------------------------------------------------------//
    // -------------------------------------- register update ------------------------------------//
    // -------------------------------------------------------------------------------------------//

    always @ (posedge clk or negedge rst_n) begin : always_async

        if (~rst_n) begin
            encdec_reg <= 1'b0;
            init_reg   <= 1'b0;
            next_reg   <= 1'b0;
            ready_reg  <= 1'b0;

            for (i = 0; i < 16; i = i + 1)
                key_reg[i] <= 16'h0;
            keylen_reg <= 1'b0;

            for (i = 0; i < 8; i = i + 1) // concurrent assignment, do not use begin
                block_reg[i] <= 16'h0;

            result_reg <= 128'b0;
            valid_reg  <= 1'b0;

            main_ctrl_reg <= CTRL_IDLE;
            counter_reg   <= 4'h0;


        end else begin
            init_reg  <= init_new;
            next_reg  <= next_new;
            ready_reg <= core_ready;

            result_reg <= core_result;
            valid_reg  <= core_valid;

            main_ctrl_reg <= main_ctrl_new;
            counter_reg   <= counter_new;

            // use main_ctrl_reg or address?
            // I guess both will work but main_ctrl_reg wait another clk
            if (main_ctrl_reg == CTRL_KEY) begin
                key_reg[counter_reg] <= data_in;
            end

            if (main_ctrl_reg == CTRL_BLOCK) begin
                block_reg[counter_reg] <= data_in;
            end
        end

    end

    // -------------------------------------------------------------------------------------------//
    // ----------------------------------- finite state machine  ---------------------------------//
    // -------------------------------------------------------------------------------------------//

    always @(*) begin : main_ctrl
        reg [3:0] num_rounds;

        init_new      = 1'b0;
        next_new      = 1'b0;
        counter_new   = 4'h0;
        main_ctrl_new = address; // BE CAREFUL!!!! Make sure there is no conflict. If the data is inputing or outputing, the main_ctrl_new should be overrided.
        tmp_data_out  = 8'b0;
        counter_inc   = 1'b0;

        // get num_rounds
        if (main_ctrl_reg == CTRL_KEY) begin
            if (keylen_reg == AES_256_BIT_KEY) begin
                num_rounds = KEY256_ROUNDS;
            end else begin
                num_rounds = KEY128_ROUNDS;
            end
        end else if(main_ctrl_reg == CTRL_BLOCK) begin
            num_rounds = BLOCK_ROUNDS;
        end else begin
            // CTRL_OUTPUT or dump
            num_rounds = OUTPUT_ROUNDS;
        end

        // process instance address assign
        // avoid that STATE wait for clk one time, and init/next/edndec/keylen wait for another clk
        if (address == ADDR_START) begin
            init_new = data_in[START_INIT_BIT];
            next_new = data_in[START_NEXT_BIT];

        end else if (address == ADDR_CONFIG) begin
            encdec_reg = data_in[CONFIG_ENCDEC_BIT];
            keylen_reg = data_in[CONFIG_KEYLEN_BIT];

        end else if (address == ADDR_RESULT) begin
            tmp_data_out = result_tmp[counter_reg];
        end

        // main state machine
        case (main_ctrl_reg)
            CTRL_IDLE : begin end

            CTRL_CONFIG : begin end

            CTRL_KEY : begin
                counter_inc = 1'b1;

                // if the state is CTRL_KEY, lock up address input. Use counter to determine if it can return to CTRL_IDLE
                if (counter_reg < num_rounds) begin
                    main_ctrl_new = CTRL_KEY;
                end
            end

            CTRL_BLOCK : begin
                counter_inc = 1'b1;
                // if the state is CTRL_KEY, lock up address input. Use counter to determine if it can return to CTRL_IDLE
                if (counter_reg < num_rounds) begin
                    main_ctrl_new = CTRL_BLOCK;
                end
            end

            CTRL_STATUS : begin
                tmp_data_out = {6'b0, valid_reg, ready_reg};
            end

            CTRL_START : begin
                tmp_data_out = {4'b0, keylen_reg, encdec_reg, next_reg, init_reg}; // can use this address to check input data
            end

            CTRL_OUTPUTING : begin
                counter_inc = 1'b1;
                if (counter_reg < num_rounds) begin
                    main_ctrl_new = CTRL_OUTPUTING;
                end
            end

            default : begin
                // if the address is invalid, fall into default
                main_ctrl_new = CTRL_IDLE;
            end
        endcase // main_ctrl_reg
    end


    // -------------------------------------------------------------------------------------------//
    // ----------------------------------------- counter  ----------------------------------------//
    // -------------------------------------------------------------------------------------------//

    always @(*) begin : counter
        // default assignments
        counter_new = 4'h0;
        if (counter_inc) begin
            counter_new = counter_reg + 1'b1;
        end
    end // counter

endmodule // AES
module AES_core (
    input          clk         , // Clock
    input          rst_n       , // Asynchronous reset active low
    input          encdec      , // Encipher or decipher
    input          init        , // call key_mem to start
    input          next        , // call encipher / decipher to start
    output         ready       , // key_mem ready
    input  [255:0] key         ,
    input          keylen      , // AES128 or AES256
    input  [127:0] block       ,
    output [127:0] result      ,
    output         result_valid  // encipher / decipher ready
);

    // ------------------------------------------------------
    // ------------------- all parameters -------------------
    // ------------------------------------------------------

    // define control state
    localparam CTRL_IDLE = 2'h0;
    localparam CTRL_INIT = 2'h1;
    localparam CTRL_NEXT = 2'h2;

    // registers
    reg [1:0] main_ctrl_reg;
    reg [1:0] main_ctrl_new;

    reg ready_reg;
    reg ready_new;

    reg result_valid_reg;
    reg result_valid_new;


    // key memory wires
    wire [127:0] round_key;
    wire         key_ready;

    // enc wires
    reg          enc_next     ;
    wire [  3:0] enc_round    ;
    wire [127:0] enc_new_block;
    wire         enc_ready    ;

    // dec wires
    reg          dec_next     ;
    wire [  3:0] dec_round    ;
    wire [127:0] dec_new_block;
    wire         dec_ready    ;

    // for MUX
    reg [127:0] muxed_new_block;
    reg [  3:0] muxed_round    ;
    reg         muxed_ready    ;

    // ------------------------------------------------------
    // ------------------- instanciation --------------------
    // ------------------------------------------------------
    AES_encipher enc (
        .clk      (clk          ),
        .rst_n    (rst_n        ),
        .next     (enc_next     ),
        .keylen   (keylen       ),
        .round    (enc_round    ),
        .round_key(round_key    ),
        .block    (block        ),
        .new_block(enc_new_block),
        .ready    (enc_ready    )
    );

    AES_decipher dec (
        .clk      (clk          ),
        .rst_n    (rst_n        ),
        .next     (dec_next     ),
        .keylen   (keylen       ),
        .round    (dec_round    ),
        .round_key(round_key    ),
        .block    (block        ),
        .new_block(dec_new_block),
        .ready    (dec_ready    )
    );

    AES_key_mem_seq key_mem (
        .clk      (clk        ),
        .rst_n    (rst_n      ),
        .key      (key        ),
        .keylen   (keylen     ),
        .init     (init       ),
        .round    (muxed_round),
        .round_key(round_key  ),
        .ready    (key_ready  )
    );

    // Concurrent connectivity for ports
    assign ready        = ready_reg;
    assign result       = muxed_new_block;
    assign result_valid = result_valid_reg;

    // ------------------------------------------------------
    // --------------------- reg update ---------------------
    // ------------------------------------------------------


    always @(posedge clk or negedge rst_n) begin : always_async
        if(~rst_n) begin
            main_ctrl_reg    <= 2'b0;
            ready_reg        <= 1'b0;
            result_valid_reg <= 1'b0;
        end else begin
            main_ctrl_reg    <= main_ctrl_new;
            ready_reg        <= ready_new;
            result_valid_reg <= result_valid_new;
            // $display("in core, key in:   %h", key[255:128]);
            // $display("in core, block in: %h", block);
        end
    end


    // ------------------------------------------------------
    // ------------------ main controller  ------------------
    // ------------------------------------------------------

    always @(*) begin : main_ctrl

        // default assignments
        main_ctrl_new    = CTRL_IDLE;
        ready_new        = 1'b0;
        result_valid_new = 1'b0;

        case (main_ctrl_reg)

            CTRL_IDLE : begin
                if (init) begin
                    main_ctrl_new = CTRL_INIT;
                end else if (next) begin
                    main_ctrl_new = CTRL_NEXT;
                end
            end

            CTRL_INIT : begin
                if (key_ready) begin
                    main_ctrl_new = CTRL_IDLE;
                    ready_new     = 1'b1;
                end else begin
                    main_ctrl_new = CTRL_INIT;
                end
            end

            CTRL_NEXT : begin
                if (muxed_ready) begin
                    main_ctrl_new    = CTRL_IDLE;
                    result_valid_new = 1'b1;
                end else begin
                    main_ctrl_new = CTRL_NEXT;
                end
            end

            default : begin end
        endcase // main_ctrl_reg
    end


    // ------------------------------------------------------
    // -------------------- multiplexer  --------------------
    // ------------------------------------------------------
    always @(*) begin : multiplexer

        enc_next = 1'b0;
        dec_next = 1'b0;

        if (encdec) begin
            enc_next        = next;
            muxed_new_block = enc_new_block;
            muxed_round     = enc_round;
            muxed_ready     = enc_ready;
        end else begin
            dec_next        = next;
            muxed_new_block = dec_new_block;
            muxed_round     = dec_round;
            muxed_ready     = dec_ready;
        end
    end

endmodule
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

        init_addRoundKey_block  = addRoundKey(block, round_key);
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
module AES_key_mem_seq (
    input  wire         clk      ,
    input  wire         rst_n    ,
    input  wire [255:0] key      ,
    input  wire         keylen   ,
    input  wire         init     ,
    input  wire [  3:0] round    ,
    output wire [127:0] round_key,
    output wire         ready
    // output wire [ 31:0] sboxw    ,
    // input  wire [ 31:0] new_sboxw
);
    wire [7:0] sbox    [255:0];
    wire [7:0] inv_sbox[255:0];
    wire [7:0] E       [255:0];
    wire [7:0] L       [255:0];

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



    assign E[8'h00] = 8'h01;
    assign E[8'h01] = 8'h03;
    assign E[8'h02] = 8'h05;
    assign E[8'h03] = 8'h0F;
    assign E[8'h04] = 8'h11;
    assign E[8'h05] = 8'h33;
    assign E[8'h06] = 8'h55;
    assign E[8'h07] = 8'hFF;
    assign E[8'h08] = 8'h1A;
    assign E[8'h09] = 8'h2E;
    assign E[8'h0a] = 8'h72;
    assign E[8'h0b] = 8'h96;
    assign E[8'h0c] = 8'hA1;
    assign E[8'h0d] = 8'hF8;
    assign E[8'h0e] = 8'h13;
    assign E[8'h0f] = 8'h35;
    assign E[8'h10] = 8'h5F;
    assign E[8'h11] = 8'hE1;
    assign E[8'h12] = 8'h38;
    assign E[8'h13] = 8'h48;
    assign E[8'h14] = 8'hD8;
    assign E[8'h15] = 8'h73;
    assign E[8'h16] = 8'h95;
    assign E[8'h17] = 8'hA4;
    assign E[8'h18] = 8'hF7;
    assign E[8'h19] = 8'h02;
    assign E[8'h1a] = 8'h06;
    assign E[8'h1b] = 8'h0A;
    assign E[8'h1c] = 8'h1E;
    assign E[8'h1d] = 8'h22;
    assign E[8'h1e] = 8'h66;
    assign E[8'h1f] = 8'hAA;
    assign E[8'h20] = 8'hE5;
    assign E[8'h21] = 8'h34;
    assign E[8'h22] = 8'h5C;
    assign E[8'h23] = 8'hE4;
    assign E[8'h24] = 8'h37;
    assign E[8'h25] = 8'h59;
    assign E[8'h26] = 8'hEB;
    assign E[8'h27] = 8'h26;
    assign E[8'h28] = 8'h6A;
    assign E[8'h29] = 8'hBE;
    assign E[8'h2a] = 8'hD9;
    assign E[8'h2b] = 8'h70;
    assign E[8'h2c] = 8'h90;
    assign E[8'h2d] = 8'hAB;
    assign E[8'h2e] = 8'hE6;
    assign E[8'h2f] = 8'h31;
    assign E[8'h30] = 8'h53;
    assign E[8'h31] = 8'hF5;
    assign E[8'h32] = 8'h04;
    assign E[8'h33] = 8'h0C;
    assign E[8'h34] = 8'h14;
    assign E[8'h35] = 8'h3C;
    assign E[8'h36] = 8'h44;
    assign E[8'h37] = 8'hCC;
    assign E[8'h38] = 8'h4F;
    assign E[8'h39] = 8'hD1;
    assign E[8'h3a] = 8'h68;
    assign E[8'h3b] = 8'hB8;
    assign E[8'h3c] = 8'hD3;
    assign E[8'h3d] = 8'h6E;
    assign E[8'h3e] = 8'hB2;
    assign E[8'h3f] = 8'hCD;
    assign E[8'h40] = 8'h4C;
    assign E[8'h41] = 8'hD4;
    assign E[8'h42] = 8'h67;
    assign E[8'h43] = 8'hA9;
    assign E[8'h44] = 8'hE0;
    assign E[8'h45] = 8'h3B;
    assign E[8'h46] = 8'h4D;
    assign E[8'h47] = 8'hD7;
    assign E[8'h48] = 8'h62;
    assign E[8'h49] = 8'hA6;
    assign E[8'h4a] = 8'hF1;
    assign E[8'h4b] = 8'h08;
    assign E[8'h4c] = 8'h18;
    assign E[8'h4d] = 8'h28;
    assign E[8'h4e] = 8'h78;
    assign E[8'h4f] = 8'h88;
    assign E[8'h50] = 8'h83;
    assign E[8'h51] = 8'h9E;
    assign E[8'h52] = 8'hB9;
    assign E[8'h53] = 8'hD0;
    assign E[8'h54] = 8'h6B;
    assign E[8'h55] = 8'hBD;
    assign E[8'h56] = 8'hDC;
    assign E[8'h57] = 8'h7F;
    assign E[8'h58] = 8'h81;
    assign E[8'h59] = 8'h98;
    assign E[8'h5a] = 8'hB3;
    assign E[8'h5b] = 8'hCE;
    assign E[8'h5c] = 8'h49;
    assign E[8'h5d] = 8'hDB;
    assign E[8'h5e] = 8'h76;
    assign E[8'h5f] = 8'h9A;
    assign E[8'h60] = 8'hB5;
    assign E[8'h61] = 8'hC4;
    assign E[8'h62] = 8'h57;
    assign E[8'h63] = 8'hF9;
    assign E[8'h64] = 8'h10;
    assign E[8'h65] = 8'h30;
    assign E[8'h66] = 8'h50;
    assign E[8'h67] = 8'hF0;
    assign E[8'h68] = 8'h0B;
    assign E[8'h69] = 8'h1D;
    assign E[8'h6a] = 8'h27;
    assign E[8'h6b] = 8'h69;
    assign E[8'h6c] = 8'hBB;
    assign E[8'h6d] = 8'hD6;
    assign E[8'h6e] = 8'h61;
    assign E[8'h6f] = 8'hA3;
    assign E[8'h70] = 8'hFE;
    assign E[8'h71] = 8'h19;
    assign E[8'h72] = 8'h2B;
    assign E[8'h73] = 8'h7D;
    assign E[8'h74] = 8'h87;
    assign E[8'h75] = 8'h92;
    assign E[8'h76] = 8'hAD;
    assign E[8'h77] = 8'hEC;
    assign E[8'h78] = 8'h2F;
    assign E[8'h79] = 8'h71;
    assign E[8'h7a] = 8'h93;
    assign E[8'h7b] = 8'hAE;
    assign E[8'h7c] = 8'hE9;
    assign E[8'h7d] = 8'h20;
    assign E[8'h7e] = 8'h60;
    assign E[8'h7f] = 8'hA0;
    assign E[8'h80] = 8'hFB;
    assign E[8'h81] = 8'h16;
    assign E[8'h82] = 8'h3A;
    assign E[8'h83] = 8'h4E;
    assign E[8'h84] = 8'hD2;
    assign E[8'h85] = 8'h6D;
    assign E[8'h86] = 8'hB7;
    assign E[8'h87] = 8'hC2;
    assign E[8'h88] = 8'h5D;
    assign E[8'h89] = 8'hE7;
    assign E[8'h8a] = 8'h32;
    assign E[8'h8b] = 8'h56;
    assign E[8'h8c] = 8'hFA;
    assign E[8'h8d] = 8'h15;
    assign E[8'h8e] = 8'h3F;
    assign E[8'h8f] = 8'h41;
    assign E[8'h90] = 8'hC3;
    assign E[8'h91] = 8'h5E;
    assign E[8'h92] = 8'hE2;
    assign E[8'h93] = 8'h3D;
    assign E[8'h94] = 8'h47;
    assign E[8'h95] = 8'hC9;
    assign E[8'h96] = 8'h40;
    assign E[8'h97] = 8'hC0;
    assign E[8'h98] = 8'h5B;
    assign E[8'h99] = 8'hED;
    assign E[8'h9a] = 8'h2C;
    assign E[8'h9b] = 8'h74;
    assign E[8'h9c] = 8'h9C;
    assign E[8'h9d] = 8'hBF;
    assign E[8'h9e] = 8'hDA;
    assign E[8'h9f] = 8'h75;
    assign E[8'ha0] = 8'h9F;
    assign E[8'ha1] = 8'hBA;
    assign E[8'ha2] = 8'hD5;
    assign E[8'ha3] = 8'h64;
    assign E[8'ha4] = 8'hAC;
    assign E[8'ha5] = 8'hEF;
    assign E[8'ha6] = 8'h2A;
    assign E[8'ha7] = 8'h7E;
    assign E[8'ha8] = 8'h82;
    assign E[8'ha9] = 8'h9D;
    assign E[8'haa] = 8'hBC;
    assign E[8'hab] = 8'hDF;
    assign E[8'hac] = 8'h7A;
    assign E[8'had] = 8'h8E;
    assign E[8'hae] = 8'h89;
    assign E[8'haf] = 8'h80;
    assign E[8'hb0] = 8'h9B;
    assign E[8'hb1] = 8'hB6;
    assign E[8'hb2] = 8'hC1;
    assign E[8'hb3] = 8'h58;
    assign E[8'hb4] = 8'hE8;
    assign E[8'hb5] = 8'h23;
    assign E[8'hb6] = 8'h65;
    assign E[8'hb7] = 8'hAF;
    assign E[8'hb8] = 8'hEA;
    assign E[8'hb9] = 8'h25;
    assign E[8'hba] = 8'h6F;
    assign E[8'hbb] = 8'hB1;
    assign E[8'hbc] = 8'hC8;
    assign E[8'hbd] = 8'h43;
    assign E[8'hbe] = 8'hC5;
    assign E[8'hbf] = 8'h54;
    assign E[8'hc0] = 8'hFC;
    assign E[8'hc1] = 8'h1F;
    assign E[8'hc2] = 8'h21;
    assign E[8'hc3] = 8'h63;
    assign E[8'hc4] = 8'hA5;
    assign E[8'hc5] = 8'hF4;
    assign E[8'hc6] = 8'h07;
    assign E[8'hc7] = 8'h09;
    assign E[8'hc8] = 8'h1B;
    assign E[8'hc9] = 8'h2D;
    assign E[8'hca] = 8'h77;
    assign E[8'hcb] = 8'h99;
    assign E[8'hcc] = 8'hB0;
    assign E[8'hcd] = 8'hCB;
    assign E[8'hce] = 8'h46;
    assign E[8'hcf] = 8'hCA;
    assign E[8'hd0] = 8'h45;
    assign E[8'hd1] = 8'hCF;
    assign E[8'hd2] = 8'h4A;
    assign E[8'hd3] = 8'hDE;
    assign E[8'hd4] = 8'h79;
    assign E[8'hd5] = 8'h8B;
    assign E[8'hd6] = 8'h86;
    assign E[8'hd7] = 8'h91;
    assign E[8'hd8] = 8'hA8;
    assign E[8'hd9] = 8'hE3;
    assign E[8'hda] = 8'h3E;
    assign E[8'hdb] = 8'h42;
    assign E[8'hdc] = 8'hC6;
    assign E[8'hdd] = 8'h51;
    assign E[8'hde] = 8'hF3;
    assign E[8'hdf] = 8'h0E;
    assign E[8'he0] = 8'h12;
    assign E[8'he1] = 8'h36;
    assign E[8'he2] = 8'h5A;
    assign E[8'he3] = 8'hEE;
    assign E[8'he4] = 8'h29;
    assign E[8'he5] = 8'h7B;
    assign E[8'he6] = 8'h8D;
    assign E[8'he7] = 8'h8C;
    assign E[8'he8] = 8'h8F;
    assign E[8'he9] = 8'h8A;
    assign E[8'hea] = 8'h85;
    assign E[8'heb] = 8'h94;
    assign E[8'hec] = 8'hA7;
    assign E[8'hed] = 8'hF2;
    assign E[8'hee] = 8'h0D;
    assign E[8'hef] = 8'h17;
    assign E[8'hf0] = 8'h39;
    assign E[8'hf1] = 8'h4B;
    assign E[8'hf2] = 8'hDD;
    assign E[8'hf3] = 8'h7C;
    assign E[8'hf4] = 8'h84;
    assign E[8'hf5] = 8'h97;
    assign E[8'hf6] = 8'hA2;
    assign E[8'hf7] = 8'hFD;
    assign E[8'hf8] = 8'h1C;
    assign E[8'hf9] = 8'h24;
    assign E[8'hfa] = 8'h6C;
    assign E[8'hfb] = 8'hB4;
    assign E[8'hfc] = 8'hC7;
    assign E[8'hfd] = 8'h52;
    assign E[8'hfe] = 8'hF6;
    assign E[8'hff] = 8'h01;

    assign L[8'h00] = 8'h00;
    assign L[8'h01] = 8'h00;
    assign L[8'h02] = 8'h19;
    assign L[8'h03] = 8'h01;
    assign L[8'h04] = 8'h32;
    assign L[8'h05] = 8'h02;
    assign L[8'h06] = 8'h1A;
    assign L[8'h07] = 8'hC6;
    assign L[8'h08] = 8'h4B;
    assign L[8'h09] = 8'hC7;
    assign L[8'h0a] = 8'h1B;
    assign L[8'h0b] = 8'h68;
    assign L[8'h0c] = 8'h33;
    assign L[8'h0d] = 8'hEE;
    assign L[8'h0e] = 8'hDF;
    assign L[8'h0f] = 8'h03;
    assign L[8'h10] = 8'h64;
    assign L[8'h11] = 8'h04;
    assign L[8'h12] = 8'hE0;
    assign L[8'h13] = 8'h0E;
    assign L[8'h14] = 8'h34;
    assign L[8'h15] = 8'h8D;
    assign L[8'h16] = 8'h81;
    assign L[8'h17] = 8'hEF;
    assign L[8'h18] = 8'h4C;
    assign L[8'h19] = 8'h71;
    assign L[8'h1a] = 8'h08;
    assign L[8'h1b] = 8'hC8;
    assign L[8'h1c] = 8'hF8;
    assign L[8'h1d] = 8'h69;
    assign L[8'h1e] = 8'h1C;
    assign L[8'h1f] = 8'hC1;
    assign L[8'h20] = 8'h7D;
    assign L[8'h21] = 8'hC2;
    assign L[8'h22] = 8'h1D;
    assign L[8'h23] = 8'hB5;
    assign L[8'h24] = 8'hF9;
    assign L[8'h25] = 8'hB9;
    assign L[8'h26] = 8'h27;
    assign L[8'h27] = 8'h6A;
    assign L[8'h28] = 8'h4D;
    assign L[8'h29] = 8'hE4;
    assign L[8'h2a] = 8'hA6;
    assign L[8'h2b] = 8'h72;
    assign L[8'h2c] = 8'h9A;
    assign L[8'h2d] = 8'hC9;
    assign L[8'h2e] = 8'h09;
    assign L[8'h2f] = 8'h78;
    assign L[8'h30] = 8'h65;
    assign L[8'h31] = 8'h2F;
    assign L[8'h32] = 8'h8A;
    assign L[8'h33] = 8'h05;
    assign L[8'h34] = 8'h21;
    assign L[8'h35] = 8'h0F;
    assign L[8'h36] = 8'hE1;
    assign L[8'h37] = 8'h24;
    assign L[8'h38] = 8'h12;
    assign L[8'h39] = 8'hF0;
    assign L[8'h3a] = 8'h82;
    assign L[8'h3b] = 8'h45;
    assign L[8'h3c] = 8'h35;
    assign L[8'h3d] = 8'h93;
    assign L[8'h3e] = 8'hDA;
    assign L[8'h3f] = 8'h8E;
    assign L[8'h40] = 8'h96;
    assign L[8'h41] = 8'h8F;
    assign L[8'h42] = 8'hDB;
    assign L[8'h43] = 8'hBD;
    assign L[8'h44] = 8'h36;
    assign L[8'h45] = 8'hD0;
    assign L[8'h46] = 8'hCE;
    assign L[8'h47] = 8'h94;
    assign L[8'h48] = 8'h13;
    assign L[8'h49] = 8'h5C;
    assign L[8'h4a] = 8'hD2;
    assign L[8'h4b] = 8'hF1;
    assign L[8'h4c] = 8'h40;
    assign L[8'h4d] = 8'h46;
    assign L[8'h4e] = 8'h83;
    assign L[8'h4f] = 8'h38;
    assign L[8'h50] = 8'h66;
    assign L[8'h51] = 8'hDD;
    assign L[8'h52] = 8'hFD;
    assign L[8'h53] = 8'h30;
    assign L[8'h54] = 8'hBF;
    assign L[8'h55] = 8'h06;
    assign L[8'h56] = 8'h8B;
    assign L[8'h57] = 8'h62;
    assign L[8'h58] = 8'hB3;
    assign L[8'h59] = 8'h25;
    assign L[8'h5a] = 8'hE2;
    assign L[8'h5b] = 8'h98;
    assign L[8'h5c] = 8'h22;
    assign L[8'h5d] = 8'h88;
    assign L[8'h5e] = 8'h91;
    assign L[8'h5f] = 8'h10;
    assign L[8'h60] = 8'h7E;
    assign L[8'h61] = 8'h6E;
    assign L[8'h62] = 8'h48;
    assign L[8'h63] = 8'hC3;
    assign L[8'h64] = 8'hA3;
    assign L[8'h65] = 8'hB6;
    assign L[8'h66] = 8'h1E;
    assign L[8'h67] = 8'h42;
    assign L[8'h68] = 8'h3A;
    assign L[8'h69] = 8'h6B;
    assign L[8'h6a] = 8'h28;
    assign L[8'h6b] = 8'h54;
    assign L[8'h6c] = 8'hFA;
    assign L[8'h6d] = 8'h85;
    assign L[8'h6e] = 8'h3D;
    assign L[8'h6f] = 8'hBA;
    assign L[8'h70] = 8'h2B;
    assign L[8'h71] = 8'h79;
    assign L[8'h72] = 8'h0A;
    assign L[8'h73] = 8'h15;
    assign L[8'h74] = 8'h9B;
    assign L[8'h75] = 8'h9F;
    assign L[8'h76] = 8'h5E;
    assign L[8'h77] = 8'hCA;
    assign L[8'h78] = 8'h4E;
    assign L[8'h79] = 8'hD4;
    assign L[8'h7a] = 8'hAC;
    assign L[8'h7b] = 8'hE5;
    assign L[8'h7c] = 8'hF3;
    assign L[8'h7d] = 8'h73;
    assign L[8'h7e] = 8'hA7;
    assign L[8'h7f] = 8'h57;
    assign L[8'h80] = 8'hAF;
    assign L[8'h81] = 8'h58;
    assign L[8'h82] = 8'hA8;
    assign L[8'h83] = 8'h50;
    assign L[8'h84] = 8'hF4;
    assign L[8'h85] = 8'hEA;
    assign L[8'h86] = 8'hD6;
    assign L[8'h87] = 8'h74;
    assign L[8'h88] = 8'h4F;
    assign L[8'h89] = 8'hAE;
    assign L[8'h8a] = 8'hE9;
    assign L[8'h8b] = 8'hD5;
    assign L[8'h8c] = 8'hE7;
    assign L[8'h8d] = 8'hE6;
    assign L[8'h8e] = 8'hAD;
    assign L[8'h8f] = 8'hE8;
    assign L[8'h90] = 8'h2C;
    assign L[8'h91] = 8'hD7;
    assign L[8'h92] = 8'h75;
    assign L[8'h93] = 8'h7A;
    assign L[8'h94] = 8'hEB;
    assign L[8'h95] = 8'h16;
    assign L[8'h96] = 8'h0B;
    assign L[8'h97] = 8'hF5;
    assign L[8'h98] = 8'h59;
    assign L[8'h99] = 8'hCB;
    assign L[8'h9a] = 8'h5F;
    assign L[8'h9b] = 8'hB0;
    assign L[8'h9c] = 8'h9C;
    assign L[8'h9d] = 8'hA9;
    assign L[8'h9e] = 8'h51;
    assign L[8'h9f] = 8'hA0;
    assign L[8'ha0] = 8'h7F;
    assign L[8'ha1] = 8'h0C;
    assign L[8'ha2] = 8'hF6;
    assign L[8'ha3] = 8'h6F;
    assign L[8'ha4] = 8'h17;
    assign L[8'ha5] = 8'hC4;
    assign L[8'ha6] = 8'h49;
    assign L[8'ha7] = 8'hEC;
    assign L[8'ha8] = 8'hD8;
    assign L[8'ha9] = 8'h43;
    assign L[8'haa] = 8'h1F;
    assign L[8'hab] = 8'h2D;
    assign L[8'hac] = 8'hA4;
    assign L[8'had] = 8'h76;
    assign L[8'hae] = 8'h7B;
    assign L[8'haf] = 8'hB7;
    assign L[8'hb0] = 8'hCC;
    assign L[8'hb1] = 8'hBB;
    assign L[8'hb2] = 8'h3E;
    assign L[8'hb3] = 8'h5A;
    assign L[8'hb4] = 8'hFB;
    assign L[8'hb5] = 8'h60;
    assign L[8'hb6] = 8'hB1;
    assign L[8'hb7] = 8'h86;
    assign L[8'hb8] = 8'h3B;
    assign L[8'hb9] = 8'h52;
    assign L[8'hba] = 8'hA1;
    assign L[8'hbb] = 8'h6C;
    assign L[8'hbc] = 8'hAA;
    assign L[8'hbd] = 8'h55;
    assign L[8'hbe] = 8'h29;
    assign L[8'hbf] = 8'h9D;
    assign L[8'hc0] = 8'h97;
    assign L[8'hc1] = 8'hB2;
    assign L[8'hc2] = 8'h87;
    assign L[8'hc3] = 8'h90;
    assign L[8'hc4] = 8'h61;
    assign L[8'hc5] = 8'hBE;
    assign L[8'hc6] = 8'hDC;
    assign L[8'hc7] = 8'hFC;
    assign L[8'hc8] = 8'hBC;
    assign L[8'hc9] = 8'h95;
    assign L[8'hca] = 8'hCF;
    assign L[8'hcb] = 8'hCD;
    assign L[8'hcc] = 8'h37;
    assign L[8'hcd] = 8'h3F;
    assign L[8'hce] = 8'h5B;
    assign L[8'hcf] = 8'hD1;
    assign L[8'hd0] = 8'h53;
    assign L[8'hd1] = 8'h39;
    assign L[8'hd2] = 8'h84;
    assign L[8'hd3] = 8'h3C;
    assign L[8'hd4] = 8'h41;
    assign L[8'hd5] = 8'hA2;
    assign L[8'hd6] = 8'h6D;
    assign L[8'hd7] = 8'h47;
    assign L[8'hd8] = 8'h14;
    assign L[8'hd9] = 8'h2A;
    assign L[8'hda] = 8'h9E;
    assign L[8'hdb] = 8'h5D;
    assign L[8'hdc] = 8'h56;
    assign L[8'hdd] = 8'hF2;
    assign L[8'hde] = 8'hD3;
    assign L[8'hdf] = 8'hAB;
    assign L[8'he0] = 8'h44;
    assign L[8'he1] = 8'h11;
    assign L[8'he2] = 8'h92;
    assign L[8'he3] = 8'hD9;
    assign L[8'he4] = 8'h23;
    assign L[8'he5] = 8'h20;
    assign L[8'he6] = 8'h2E;
    assign L[8'he7] = 8'h89;
    assign L[8'he8] = 8'hB4;
    assign L[8'he9] = 8'h7C;
    assign L[8'hea] = 8'hB8;
    assign L[8'heb] = 8'h26;
    assign L[8'hec] = 8'h77;
    assign L[8'hed] = 8'h99;
    assign L[8'hee] = 8'hE3;
    assign L[8'hef] = 8'hA5;
    assign L[8'hf0] = 8'h67;
    assign L[8'hf1] = 8'h4A;
    assign L[8'hf2] = 8'hED;
    assign L[8'hf3] = 8'hDE;
    assign L[8'hf4] = 8'hC5;
    assign L[8'hf5] = 8'h31;
    assign L[8'hf6] = 8'hFE;
    assign L[8'hf7] = 8'h18;
    assign L[8'hf8] = 8'h0D;
    assign L[8'hf9] = 8'h63;
    assign L[8'hfa] = 8'h8C;
    assign L[8'hfb] = 8'h80;
    assign L[8'hfc] = 8'hC0;
    assign L[8'hfd] = 8'hF7;
    assign L[8'hfe] = 8'h70;
    assign L[8'hff] = 8'h07;
    localparam AES_128_BIT_KEY = 1'b0;
    localparam AES_256_BIT_KEY = 1'b1;

    localparam AES_128_NUM_ROUNDS = 10;
    localparam AES_256_NUM_ROUNDS = 14;

    localparam CTRL_IDLE     = 3'h0;
    localparam CTRL_INIT     = 3'h1;
    localparam CTRL_GENERATE = 3'h2;
    localparam CTRL_DONE     = 3'h3;

    reg [127:0] key_mem    [0:14];
    reg [127:0] key_mem_new      ;
    reg         key_mem_we       ;

    reg [127:0] prev_key0_reg;
    reg [127:0] prev_key0_new;
    reg         prev_key0_we ;

    reg [127:0] prev_key1_reg;
    reg [127:0] prev_key1_new;
    reg         prev_key1_we ;

    reg [3:0] round_ctr_reg;
    reg [3:0] round_ctr_new;
    reg       round_ctr_rst;
    reg       round_ctr_inc;
    reg       round_ctr_we ;

    reg [2:0] key_mem_ctrl_reg;
    reg [2:0] key_mem_ctrl_new;
    reg       key_mem_ctrl_we ;

    reg ready_reg;
    reg ready_new;
    reg ready_we ;

    reg [7:0] rcon_reg ;
    reg [7:0] rcon_new ;
    reg       rcon_we  ;
    reg       rcon_set ;
    reg       rcon_next;

    // reg [31:0] tmp_sboxw;

    reg         round_key_update;
    reg [127:0] tmp_round_key   ;


    assign round_key = tmp_round_key;
    assign ready     = ready_reg;
    // assign sboxw     = tmp_sboxw;

    always @ (posedge clk or negedge rst_n) begin : reg_update
        integer i;

        if (!rst_n) begin
            for (i = 0 ; i <= AES_256_NUM_ROUNDS ; i = i + 1)
                key_mem[i] <= 128'h0;

            rcon_reg         <= 8'h0;
            ready_reg        <= 1'b0;
            round_ctr_reg    <= 4'h0;
            key_mem_ctrl_reg <= CTRL_IDLE;
        end else begin
            if (round_ctr_we)
                round_ctr_reg <= round_ctr_new;

            if (ready_we)
                ready_reg <= ready_new;

            if (rcon_we)
                rcon_reg <= rcon_new;

            if (key_mem_we)
                key_mem[round_ctr_reg] <= key_mem_new;

            if (prev_key0_we)
                prev_key0_reg <= prev_key0_new;

            if (prev_key1_we)
                prev_key1_reg <= prev_key1_new;

            if (key_mem_ctrl_we)
                key_mem_ctrl_reg <= key_mem_ctrl_new;
        end
    end
    always @* begin : key_mem_read
        tmp_round_key = key_mem[round];
    end


    always @* begin : round_key_gen
        reg [31 : 0] w0, w1, w2, w3, w4, w5, w6, w7;
        reg [31 : 0] k0, k1, k2, k3;
        reg [31 : 0] rconw, rotstw, tw, trw;
        key_mem_new   = 128'h0;
        key_mem_we    = 1'b0;
        prev_key0_new = 128'h0;
        prev_key0_we  = 1'b0;
        prev_key1_new = 128'h0;
        prev_key1_we  = 1'b0;

        k0        = 32'h0;
        k1        = 32'h0;
        k2        = 32'h0;
        k3        = 32'h0;
        rcon_set  = 1'b1;
        rcon_next = 1'b0;
        w0        = prev_key0_reg[127 : 096];
        w1        = prev_key0_reg[095 : 064];
        w2        = prev_key0_reg[063 : 032];
        w3        = prev_key0_reg[031 : 000];

        w4 = prev_key1_reg[127 : 096];
        w5 = prev_key1_reg[095 : 064];
        w6 = prev_key1_reg[063 : 032];
        w7 = prev_key1_reg[031 : 000];

        rconw = {rcon_reg, 24'h0};
        // tmp_sboxw = w7;

        // rotstw    = {new_sboxw[23 : 00], new_sboxw[31 : 24]};
        // trw       = rotstw ^ rconw;
        // tw        = new_sboxw;

        tw[31:24] = sbox[w7[31:24]];
        tw[23:16] = sbox[w7[23:16]];
        tw[15:8]  = sbox[w7[15:8]];
        tw[7:0]   = sbox[w7[7:0]];

        rotstw = {tw[23 : 00], tw[31 : 24]};
        trw    = rotstw ^ rconw;
        // tw        = new_sboxw;

        if (round_key_update) begin
            rcon_set   = 1'b0;
            key_mem_we = 1'b1;
            case (keylen)
                AES_128_BIT_KEY : begin
                    if (round_ctr_reg == 0) begin
                        key_mem_new   = key[255 : 128];
                        prev_key1_new = key[255 : 128];
                        prev_key1_we  = 1'b1;
                        rcon_next     = 1'b1;
                    end else begin
                        k0 = w4 ^ trw;
                        k1 = w5 ^ w4 ^ trw;
                        k2 = w6 ^ w5 ^ w4 ^ trw;
                        k3 = w7 ^ w6 ^ w5 ^ w4 ^ trw;

                        key_mem_new   = {k0, k1, k2, k3};
                        prev_key1_new = {k0, k1, k2, k3};
                        prev_key1_we  = 1'b1;
                        rcon_next     = 1'b1;
                    end
                end

                AES_256_BIT_KEY : begin
                    if (round_ctr_reg == 0) begin
                        key_mem_new   = key[255 : 128];
                        prev_key0_new = key[255 : 128];
                        prev_key0_we  = 1'b1;
                    end else if (round_ctr_reg == 1) begin
                        key_mem_new   = key[127 : 0];
                        prev_key1_new = key[127 : 0];
                        prev_key1_we  = 1'b1;
                        rcon_next     = 1'b1;
                    end else begin
                        if (round_ctr_reg[0] == 0) begin
                            k0 = w0 ^ trw;
                            k1 = w1 ^ w0 ^ trw;
                            k2 = w2 ^ w1 ^ w0 ^ trw;
                            k3 = w3 ^ w2 ^ w1 ^ w0 ^ trw;
                        end else begin
                            k0        = w0 ^ tw;
                            k1        = w1 ^ w0 ^ tw;
                            k2        = w2 ^ w1 ^ w0 ^ tw;
                            k3        = w3 ^ w2 ^ w1 ^ w0 ^ tw;
                            rcon_next = 1'b1;
                        end
                        key_mem_new   = {k0, k1, k2, k3};
                        prev_key1_new = {k0, k1, k2, k3};
                        prev_key1_we  = 1'b1;
                        prev_key0_new = prev_key1_reg;
                        prev_key0_we  = 1'b1;
                    end
                end

                default :
                    begin
                    end
            endcase
        end
    end
    always @* begin : rcon_logic
        reg [7 : 0] tmp_rcon;
        rcon_new = 8'h00;
        rcon_we  = 1'b0;

        tmp_rcon = {rcon_reg[6 : 0], 1'b0} ^ (8'h1b & {8{rcon_reg[7]}});

        if (rcon_set) begin
            rcon_new = 8'h8d;
            rcon_we  = 1'b1;
        end

        if (rcon_next) begin
            rcon_new = tmp_rcon[7 : 0];
            rcon_we  = 1'b1;
        end
    end


    always @* begin : round_ctr
        round_ctr_new = 4'h0;
        round_ctr_we  = 1'b0;

        if (round_ctr_rst) begin
            round_ctr_new = 4'h0;
            round_ctr_we  = 1'b1;
        end else if (round_ctr_inc) begin
            round_ctr_new = round_ctr_reg + 1'b1;
            round_ctr_we  = 1'b1;
        end
    end


    always @* begin : key_mem_ctrl
        reg [3 : 0] num_rounds;
        ready_new        = 1'b0;
        ready_we         = 1'b0;
        round_key_update = 1'b0;
        round_ctr_rst    = 1'b0;
        round_ctr_inc    = 1'b0;
        key_mem_ctrl_new = CTRL_IDLE;
        key_mem_ctrl_we  = 1'b0;

        if (keylen == AES_128_BIT_KEY)
            num_rounds = AES_128_NUM_ROUNDS;
        else
            num_rounds = AES_256_NUM_ROUNDS;

        case(key_mem_ctrl_reg)
            CTRL_IDLE : begin
                if (init) begin
                    ready_new        = 1'b0;
                    ready_we         = 1'b1;
                    key_mem_ctrl_new = CTRL_INIT;
                    key_mem_ctrl_we  = 1'b1;
                end
            end

            CTRL_INIT : begin
                round_ctr_rst    = 1'b1;
                key_mem_ctrl_new = CTRL_GENERATE;
                key_mem_ctrl_we  = 1'b1;
            end

            CTRL_GENERATE : begin
                round_ctr_inc    = 1'b1;
                round_key_update = 1'b1;
                if (round_ctr_reg == num_rounds) begin
                    key_mem_ctrl_new = CTRL_DONE;
                    key_mem_ctrl_we  = 1'b1;
                end
            end

            CTRL_DONE : begin
                ready_new        = 1'b1;
                ready_we         = 1'b1;
                key_mem_ctrl_new = CTRL_IDLE;
                key_mem_ctrl_we  = 1'b1;
            end

            default : begin end
        endcase
    end
endmodule 
