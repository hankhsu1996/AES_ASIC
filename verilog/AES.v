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

    localparam ADDR_STATUS      = 4'h4;
    localparam STATUS_READY_BIT = 0   ; // not used.
    localparam STATUS_READY_BIT = 1   ;

    localparam ADDR_START     = 4'hf;
    localparam START_INIT_BIT = 0   ;
    localparam START_NEXT_BIT = 1   ;

    localparam ADDR_RESULT = 4'h5;

    // -------------------------------------------------------------------------------------//
    // ------------------------------- finite state machine --------------------------------//
    // -------------------------------------------------------------------------------------//

    localparam CTRL_IDLE    = 4'h0;
    localparam CTRL_CONFIG  = 4'h1;
    localparam CTRL_KEY     = 4'h2;
    localparam CTRL_BLOCK   = 4'h3;
    localparam CTRL_READING = 4'h4;
    localparam CTRL_STATUS  = 4'h5;
    localparam CTRL_MAIN    = 4'h6;
    localparam CTRL_


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
    wire [15:0] tmp_data_out;

    // for state machine counter
    reg [3:0] main_ctrl_reg;
    reg [3:0] main_ctrl_new;
    reg [3:0] counter_reg  ;
    reg [3:0] counter_new  ;
    integer   i            ;


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
                key_reg <= 16'h0;
            keylen_reg <= 1'b0;

            for (i = 0; i < 7; i = i + 1) // concurrent assignment, do not use begin
                block_reg <= 16'h0;

            result_reg <= 128'b0;
            valid_reg  <= 1'b0;

            counter_reg <= 4'h0;

        end else begin
            init_reg  <= init_new;
            next_reg  <= next_new;
            ready_reg <= core_ready;

            result_reg <= core_result;
            valid_reg  <= core_valid;

            counter_reg <= counter_new;

            // init reg, next reg, key reg, kenlen reg, block reg

            //







            init_reg <= init_new;
            next_reg <= next_new;

            ready_reg <= core_ready;
            valid_reg <= core_valid;

            result_reg <= core_result;

            if (write_key) begin
                key_reg[counter] <= data_in;
                counter          <= ((counter == 4'hf)? 4'h0: counter + 1);
            end

            if (write_block) begin
                block_reg[counter] <= data_in;
                counter            <= ((counter == 4'h7)? 4'h0: counter + 1);
            end

            if (config_we) begin
                encdec_reg <= data_in[CTRL_ENCDEC_BIT];
                keylen_reg <= data_in[CTRL_KEYLEN_BIT];
            end

            if (result_wo) begin
                tmp_read_data <= result_reg[(15 - counter) * 8 +: 8];
                counter       <= ((counter == 4'hf)? 4'h0: counter + 1);
            end

        end

    end

    // -------------------------------------------------------------------------------------------//
    // ----------------------------------- finite state machine  ---------------------------------//
    // -------------------------------------------------------------------------------------------//

    always @ * begin
        write_key     = 1'b0;
        write_block   = 1'b0;
        config_we     = 1'b0;
        init_new      = 1'b0;
        next_new      = 1'b0;
        tmp_read_data = 32'h0;
        result_wo     = 1'b0;

        case (address)
            WRITE_KEY : begin write_key = 1'b1;
                tmp_read_data = {4'h0, counter};
            end
            WRITE_BLOCK : begin write_block = 1'b1;
                tmp_read_data = {4'h0, counter};
            end

            STATUS : tmp_read_data = {6'h0, valid_reg, ready_reg};
            CONFIG : config_we = 1'b1;
            START  : begin init_new = data_in[CTRL_INIT_BIT];
                next_new      = data_in[CTRL_NEXT_BIT];
                tmp_read_data = {4'h0, keylen_reg, encdec_reg, next_reg, init_reg};
            end
            RESULT_OUT : result_wo = 1'b1;

        endcase // address

    end






endmodule // AES
