`include "AES_core.v"

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

    localparam ADDR_CONFIG       = 4'h1;
    localparam CONFIG_ENCDEC_BIT = 0   ;
    localparam CONFIG_KEYLEN_BIT = 1   ;

    localparam ADDR_KEY = 4'h2;

    localparam ADDR_BLOCK = 4'h3;

    localparam ADDR_STATUS      = 4'h5;
    localparam STATUS_READY_BIT = 0   ; // not used.
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
    localparam CTRL_MAIN      = 4'h6;
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

    reg  [127:0] result_reg ;
    wire [127:0] core_result;
    reg          valid_reg  ;
    wire         core_valid ;

    // according to current state, output corresponding data
    reg [15:0] tmp_data_out;

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

            for (i = 0; i < 15; i = i + 1)
                key_reg[i] <= 16'h0;
            keylen_reg <= 1'b0;

            for (i = 0; i < 7; i = i + 1) // concurrent assignment, do not use begin
                block_reg[i] <= 16'h0;

            result_reg <= 128'b0;
            valid_reg  <= 1'b0;

            main_ctrl_reg <= CTRL_IDLE;
            counter_reg <= 4'h0;


        end else begin
            init_reg  <= init_new;
            next_reg  <= next_new;
            ready_reg <= core_ready;

            result_reg <= core_result;
            valid_reg  <= core_valid;

            main_ctrl_reg <= main_ctrl_new;
            counter_reg <= counter_new;

            // init reg, next reg, key reg, kenlen reg, block reg

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
        tmp_data_out  = 16'b0;
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

        // $display("case: %h", main_ctrl_reg);

        case (main_ctrl_reg)
            CTRL_IDLE : begin end

            CTRL_CONFIG : begin
                encdec_reg = data_in[CONFIG_ENCDEC_BIT];
                keylen_reg = data_in[CONFIG_KEYLEN_BIT];
            end

            CTRL_KEY : begin
                counter_inc = 1'b1;
                // if the state is CTRL_KEY, lock up address input. Use counter to determine if it can return to CTRL_IDLE
                if (counter_reg < num_rounds) begin
                    main_ctrl_new = CTRL_KEY;
                end else begin
                    main_ctrl_new = CTRL_IDLE;
                end
            end

            CTRL_BLOCK : begin
                counter_inc = 1'b1;
                // if the state is CTRL_KEY, lock up address input. Use counter to determine if it can return to CTRL_IDLE
                if (counter_reg < num_rounds) begin
                    main_ctrl_new = CTRL_BLOCK;
                end else begin
                    main_ctrl_new = CTRL_IDLE;
                end
            end

            CTRL_STATUS : begin
                tmp_data_out = {6'b0, valid_reg, ready_reg};
            end

            CTRL_MAIN : begin
                init_new = data_in[START_INIT_BIT];
                next_new = data_in[START_NEXT_BIT];
                tmp_data_out = {4'b0, keylen_reg, encdec_reg, next_reg, init_reg}; // can use this address to check input data
            end

            CTRL_OUTPUTING : begin
                counter_inc = 1'b1;
                if (counter_reg < num_rounds) begin
                    main_ctrl_new = CTRL_BLOCK;
                end else begin
                    main_ctrl_new = CTRL_IDLE;
                end
            end

            default : begin
                // if the address is invalid, fall into default
                // $display("error: entering default section");
                // $display("main_ctrl_reg is %h", main_ctrl_reg);
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
