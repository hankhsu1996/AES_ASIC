module aes( 
clk,
reset_n,
[3:0] control,
[15:0] write_data,
[7:0] data_out);

//-------------------------------------------I/O------------------------------------------//
input clk;
input reset_n;
input [7:0] address;
input [15:0] write_data;
output [7:0] data_out;
//----------------------------------------------------------------------------------------//

//---------------------------------------CONTROL DETAILS----------------------------------//
localparam BLOCK_WE = 4'h1;
localparam KEY_WE = 4'h2;

localparam STATUS = 4'h3;// tell user whether key is ready or result is available

localparam CONFIG = 4'h4; 
localparam CTRL_ENCDEC_BIT = 0;//bit that decide enc or dec
localparam CTRL_KEYLEN_BIT = 1;//bit that decide 128 or 256

localparam CTRL = 4'h5;
localparam CTRL_INIT_BIT = 0;//bit tell key generator it's time to generate keys 
localparam CTRL_NEXT_BIT = 1;//bit tell core the process can be start

localparam RESULT_OUT = 4'h6;//take out result

//----------------------------------------------------------------------------------------//

//------------------------------------------REGISTER--------------------------------------//
reg [15:0] block_reg [0:7];//receive 16 bits everytime
reg block_we;

reg [15:0] key_reg [0:15];//receive in 16 bits everytime
reg key_we;

reg [3:0] counter;//decide index count from 0 to 15

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

reg result_wo;
//----------------------------------------------------------------------------------------//

//------------------------------------------WIRE------------------------------------------//
wire [255:0] core_key;//original key input
wire [127:0] core_block;//text content 

wire core_init;
wire core_next;

wire core_keylen;//0->128 1->256
wire core_encdec;

wire core_valid;
wire core_ready;
wire [127 : 0] core_result;

wire [15:0] tmp_read_data;
//----------------------------------------------------------------------------------------//

//------------------------------------------ASSIGN----------------------------------------//
assign core_key = {key_reg[0], key_reg[1], key_reg[2], key_reg[3],key_reg[4], key_reg[5], key_reg[6], key_reg[7]
                   key_reg[8], key_reg[9], key_reg[10], key_reg[11],key_reg[12], key_reg[13], key_reg[14], key_reg[15]};
assign core_block  = {block_reg[0], block_reg[1], block_reg[2], block_reg[3],block_reg[5], block_reg[6], block_reg[7]};

assign core_keylen = keylen_reg;
assign core_encdec = encdec_reg;

assign core_init = init_reg;
assign core_next   = next_reg;

assign data_out = tmp_read_data;
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
    config_we  = 1'b0;
    init_new = 1'b0;
    next_new      = 1'b0;
    tmp_read_data = 32'h0;
    result_wo = 1'b0;

    case (control)
        KEY_WE:     key_we = 1'b1;
        BLOCK_WE:   block_we = 1'b1;

        STATUS:     tmp_read_data = {14'h0, valid_reg, ready_reg};
        CONFIG:     config_we = 1'b1;
        CTRL:       begin init_new = write_data[CTRL_INIT_BIT];
                        next_new = write_data[CTRL_NEXT_BIT];
                        tmp_read_data = {12'h0, keylen_reg, encdec_reg, next_reg, init_reg};
                    end
        RESULT_OUT: result_wo = 1'b1;
     
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

        counter <= 4'h0;
        init_reg <= 1'b0;
        next_reg <= 1'b0;
        keylen_reg <= 1'b0;
        valid_reg  <= 1'b0;
        ready_reg  <= 1'b0;
        result_reg <= 128'h0;
        
    end
    else begin
        init_reg <= init_new;
        next_reg   <= next_new;

        ready_reg  <= core_ready;
        valid_reg  <= core_valid;

        result_reg <= core_result;

        if (key_we) begin
            key_reg[counter] <= write_data;
            counter <= ((counter == 4'hf)? 4'h0: counter + 1);
        end

        if (block_we) begin
            block_reg[counter] <= write_data;
            counter <= ((counter == 4'h7)? 4'h0: counter + 1);
        end

        if (config_we) begin
            encdec_reg <= write_data[CTRL_ENCDEC_BIT];
            keylen_reg <= write_data[CTRL_KEYLEN_BIT];
        end

        if (result_wo) begin
            tmp_read_data <= result_reg[(15 - counter) * 8 +: 8];
            counter <= ((counter == 4'hf)? 4'h0: counter + 1);
        end

    end

end
//----------------------------------------------------------------------------------------//



endmodule // aes
