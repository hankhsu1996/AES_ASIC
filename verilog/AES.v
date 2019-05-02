module aes( 
clk,
reset_n,
[7:0] address,
[15:0] write_data,
[15:0] read_data);
//-------------------------------------------I/O------------------------------------------//
input clk;
input reset_n;
input [7:0] address;
input [15:0] write_data;
output [15:0] read_data;
//----------------------------------------------------------------------------------------//

//---------------------------------------ADDRESS DETAILS----------------------------------//
//000 0 ****
localparam KEY_0 = 8'h0;
localparam KEY_15 = 8'h0f;
//000 1 0***
localparam BLOCK_0 = 8'h10;
localparam BLOCK_7 = 8'h17; 
//001 00***
localparam RESULT_0 = 8'h20;
localparam RESULT_7 = 8'h27;
//010 000**
localparam CONFIG = 3'h2; 
localparam CTRL_ENCDEC_BIT = 0;//bit that decide enc or dec
localparam CTRL_KEYLEN_BIT = 1;//bit that decide 128 or 256
//011 000**
localparam STATUS = 3'h3;
localparam STATUS_READY_BIT = 0;
localparam STATUS_VALID_BIT = 1;
//100 000**
localparam ADDR_CTRL = 3'h4;
localparam CTRL_INIT_BIT = 0;
localparam CTRL_NEXT_BIT = 1;
//----------------------------------------------------------------------------------------//

//------------------------------------------REGISTER--------------------------------------//
reg [15:0] block_reg [0:7];//receive 16 bits everytime
reg block_we;

reg [15:0] key_reg [0:15];//receive in 16 bits everytime
reg key_we;

reg init_reg;//tell core it is the first time
reg init_new;//connect to input of register init_reg

reg next_reg;
reg next_new;

reg [127:0] result_reg;//connect to output of core

reg config_we;//enable chosen mode 
reg keylen_reg;
reg encdec_reg;

reg valid_reg;
reg ready_reg;
//----------------------------------------------------------------------------------------//

//------------------------------------------WIRE------------------------------------------//
wire [255:0] core_key;//original key input
wire [127:0] core_block;//text content 

wire core_init;//initial param ->seem to start to work on encipher or decoder
wire core_next;
wire core_keylen;//0->128 1->256
wire core_valid;
wire core_ready;
wire core_encdec;
wire [127 : 0] core_result;

wire [15:0] tmp_read_data;// connect to read_data
//----------------------------------------------------------------------------------------//

//------------------------------------------ASSIGN----------------------------------------//
assign core_key = {key_reg[0], key_reg[1], key_reg[2], key_reg[3],key_reg[4], key_reg[5], key_reg[6], key_reg[7]
                   key_reg[8], key_reg[9], key_reg[10], key_reg[11],key_reg[12], key_reg[13], key_reg[14], key_reg[15]};
assign core_block  = {block_reg[0], block_reg[1], block_reg[2], block_reg[3],block_reg[5], block_reg[6], block_reg[7]};
assign core_init = init_reg;
assign core_next   = next_reg;
assign core_keylen = keylen_reg;
assign core_encdec = encdec_reg;

assign read_data = tmp_read_data;
//----------------------------------------------------------------------------------------//

//---------------------------------------core instantiation-------------------------------//
aes_core core( .clk(clk), .reset_n(reset_n), .encdec(core_encdec), .init(core_init),
               .next(core_next), .ready(core_ready), .key(core_key), .keylen(core_keylen),
               .block(core_block), .result(core_result), .result_valid(core_valid) );
//----------------------------------------------------------------------------------------//

//---------------------------------finite state machine part------------------------------//
always @ * begin
    key_we = 1'b0;
    block_we  = 1'b0;
    init_new = 1'b0;
    next_new      = 1'b0;
    config_we     = 1'b0;
    tmp_read_data = 32'h0;

    if ((address >= KEY_0) && (address <= KEY_15))
        key_we = 1'b1;

    if ((address >= BLOCK_0) && (address <= BLOCK_7))
        block_we = 1'b1;

    if ((address >= RESULT_0) && (address <= RESULT_7))
        tmp_read_data = result_reg[(7 - (address - RESULT_0)) * 16 +: 16];

    case (address[7:5])
        CONFIG:  config_we = 1'b1;
        CTRL:    tmp_read_data = {12'h0, keylen_reg, encdec_reg, next_reg, init_reg};
        STATUS:  tmp_read_data = {14'h0, valid_reg, ready_reg};
        ADDR_CTRL: begin init_new = address[CTRL_INIT_BIT];
                         next_new = address[CTRL_NEXT_BIT];
                   end
    endcase // address

end
//----------------------------------------------------------------------------------------//


//------------------------------------------register update-------------------------------//
always @ (posedge clk or negedge reset_n) begin
    
    if (!reset_n) begin
        integer i;
        for (i=0; i<7; i=i+1)
             block_reg <= 16'h0;

        for (i=0; i<15; i=i+1)
             key_reg <= 16'h0;

        init_reg <= 1'b0;
        next_reg <= 1'b0;
        keylen_reg <= 1'b0;
        valid_reg  <= 1'b0;
        ready_reg  <= 1'b0;
        result_reg <= 128'h0;


    end
    else begin
        init_reg <= init_new;
        ready_reg  <= core_ready;
        valid_reg  <= core_valid;
        result_reg <= core_result;
        init_reg   <= init_new;
        next_reg   <= next_new;

        if (key_we)
            key_reg[address[3 : 0]] <= write_data;

        if (block_we)
            block_reg[address[2 : 0]] <= write_data;

        if (config_we) begin
            encdec_reg <= address[CTRL_ENCDEC_BIT];
            keylen_reg <= address[CTRL_KEYLEN_BIT];
        end

    end

end
//----------------------------------------------------------------------------------------//



endmodule // aes