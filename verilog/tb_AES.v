`include "AES.v"
`timescale 1ns/1ps
`define HALF_CYCLE 1
`define TEST_LEN_128 1
`define TEST_LEN_256 1

module tb_AES ();

	// address
	localparam ADDR_IDLE = 4'h0;

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

	// other parameters
	localparam AES_128_BIT_KEY = 1'h0;
	localparam AES_256_BIT_KEY = 1'h1;

	localparam KEY128_ROUNDS = 4'h8;
	localparam KEY256_ROUNDS = 4'hf;
	localparam BLOCK_ROUNDS  = 4'h8;
	localparam OUTPUT_ROUNDS = 4'hf;

	// declare reg and wire
	// for AES module
	reg         clk, rst_n;
	reg  [ 3:0] address ;
	reg  [15:0] data_in ;
	wire [ 7:0] data_out;

	// for testbench use
	reg encdec;
	reg init  ;
	reg next  ;
	reg keylen;

	reg  [  7:0] result_tmp[15:0];
	wire [127:0] result          ;
	assign result = {
		result_tmp[0], result_tmp[1], result_tmp[2], result_tmp[3],
		result_tmp[4], result_tmp[5], result_tmp[6], result_tmp[7],
		result_tmp[8], result_tmp[9], result_tmp[10], result_tmp[11],
		result_tmp[12], result_tmp[13], result_tmp[14], result_tmp[15]
	};

	reg [127:0] mem_block_128[   0:`TEST_LEN_128-1];
	reg [127:0] mem_key_128  [0:`TEST_LEN_128*11-1];
	reg [127:0] golden_128   [   0:`TEST_LEN_128-1];
	reg [127:0] mem_block_256[   0:`TEST_LEN_256-1];
	reg [127:0] mem_key_256  [0:`TEST_LEN_256*15-1];
	reg [127:0] golden_256   [   0:`TEST_LEN_256-1];

	reg  [127:0] block         ;
	wire [ 15:0] block_tmp[7:0];
	assign block_tmp[0] = block[16*8-1:16*7];
	assign block_tmp[1] = block[16*7-1:16*6];
	assign block_tmp[2] = block[16*6-1:16*5];
	assign block_tmp[3] = block[16*5-1:16*4];
	assign block_tmp[4] = block[16*4-1:16*3];
	assign block_tmp[5] = block[16*3-1:16*2];
	assign block_tmp[6] = block[16*2-1:16*1];
	assign block_tmp[7] = block[16*1-1:16*0];

	reg  [128:0] key         ;
	wire [ 15:0] key_tmp[7:0];
	assign key_tmp[0] = key[16*8-1:16*7];
	assign key_tmp[1] = key[16*7-1:16*6];
	assign key_tmp[2] = key[16*6-1:16*5];
	assign key_tmp[3] = key[16*5-1:16*4];
	assign key_tmp[4] = key[16*4-1:16*3];
	assign key_tmp[5] = key[16*3-1:16*2];
	assign key_tmp[6] = key[16*2-1:16*1];
	assign key_tmp[7] = key[16*1-1:16*0];

	integer i, j, err_count;


	// generate clock
	always #(`HALF_CYCLE) clk = ~clk;


	AES AES (
		.clk     (clk     ),
		.rst_n   (rst_n   ),
		.address (address ),
		.data_in (data_in ),
		.data_out(data_out)
	);

	// dump vars
	initial begin
		$dumpfile("AES.vcd");

		// 0: all, 1: this layer, 2: this and next layer
		$dumpvars(2, tb_AES);
	end

	// read from file
	initial begin
		// $readmemh("./DAT/data_AES128_core.txt", mem_block_128);
		// $readmemh("./DAT/data_keyGen128.txt", mem_key_128);
		// $readmemh("./DAT/golden_AES128_core.txt", golden_128);
		$readmemh("./DAT/data_AES256_core.txt", mem_block_256);
		$readmemh("./DAT/data_keyGen256.txt", mem_key_256);
		$readmemh("./DAT/golden_AES256_core.txt", golden_256);
	end

	initial begin
		// AES128 encryption
		$display("AES128 encryption\n");
		clk = 1'b1;
		rst_n = 1'b1;
		encdec = 1'b1;
		init = 1'b0;
		next = 1'b0;
		keylen = 1'h0;
		err_count = 0;
		address = 4'b0;
		data_in = 16'b0;

		// reset
		@(negedge clk)
			rst_n = 1'b0;

		// start
		@(negedge clk)
			rst_n = 1'b1;

		// check if the data_out is 0
		if (data_out != 8'b0) begin
			$display("fail the test: ");
			$display("At the beginning, the data_out should be %8b but the actual data_out is %8b", 8'b0, data_out);
			err_count = err_count + 1;
		end

		// after several clocks, the data_out should be 0
		#(`HALF_CYCLE*6);
		if (data_out != 8'b0) begin
			$display("fail the test: ");
			$display("At the 5th clk, the data_out should be %8b but the actual data_out is %8b", 8'b0, data_out);
			err_count = err_count + 1;
		end

		// address still maintain 0. Try some data_in
		data_in = 16'habcd;
		if (data_out != 8'b0) begin
			$display("fail the test: ");
			$display("With messy data_in, the data_out should be %8b but the actual data_out is %8b", 8'b0, data_out);
			err_count = err_count + 1;
		end
		#(`HALF_CYCLE*2);
		if (data_out != 8'b0) begin
			$display("fail the test: ");
			$display("With messy data_in, the data_out should be %8b but the actual data_out is %8b", 8'b0, data_out);
			err_count = err_count + 1;
		end

		// check the value of keylen, encdec, next, init before configuration
		address = ADDR_START;
		data_in = 16'b0;
		#(`HALF_CYCLE*2);
		if (data_out != 8'b0) begin
			$display("fail the test: ");
			$display("With messy data_in, the data_out should be %8b but the actual data_out is %8b", 8'b0, data_out);
			err_count = err_count + 1;
		end

		// start to configure. check the congiguration result
		// be careful that when we use the CTRL_START to check the configuration, we should pull down the data_in
		address = ADDR_CONFIG;
		data_in[CONFIG_ENCDEC_BIT] = 1;
		data_in[CONFIG_KEYLEN_BIT] = 1;

		#(`HALF_CYCLE*20);
		address = ADDR_START;
		data_in = 16'b0;

		#(`HALF_CYCLE*2)
			address = ADDR_IDLE;
		if (data_out != {8'b00001100}) begin
			$display("fail the test: ");
			$display("After configuring, the data_out should be %8b but the actual data_out is %8b", 8'b00001100, data_out);
			err_count = err_count + 1;
		end

		// new encdec is set to 1, and keylen is set to 1 (AES256 encryption)
		// we can now start to input the key

		// TODO
		// for (i = 0; i)

		
		#(`HALF_CYCLE*2)
			address = ADDR_KEY;

		// wait util the next clk because of the state machine mechanism
		key = mem_key_256[0*15+0];
		for (j = 0; j < 8; j = j + 1) begin
			#(`HALF_CYCLE*2);
			data_in = key_tmp[j];
		end

		key = mem_key_256[0*15+1];
		for (j = 0; j < 8; j = j + 1) begin
			#(`HALF_CYCLE*2);
			data_in = key_tmp[j];
		end

		// after inputing the key, change the address to START
		address = ADDR_START;

		// FSM changes to start state, set init to start the key generation1
		#(`HALF_CYCLE*2)
			address = ADDR_STATUS;
		data_in = 16'b0;
		data_in[START_INIT_BIT] = 1;

		// pull down the init bit
		#(`HALF_CYCLE*2)
			data_in[START_INIT_BIT] = 0;

		// wait until the data_out[ready] is pulled up to 1
		while (data_out != 8'h01) begin
			@(negedge clk)
				data_in = 16'b0;
		end

		// prepare to input the block
		#(`HALF_CYCLE*2);
			address = ADDR_BLOCK;

		block = mem_block_256[0];
		for (j = 0; j < 8; j = j + 1) begin
			#(`HALF_CYCLE*2);
			data_in = block_tmp[j];
		end

		// after last round, start the encipher
		address = ADDR_START;

		#(`HALF_CYCLE*2)
			address = ADDR_STATUS;
		data_in = 16'b0;
		data_in[START_NEXT_BIT] = 1;;

		// wait until the data_out[valid] is pulled up to 1
		while (data_out != 8'h02) begin
			@(negedge clk)
				data_in = 16'b0;
		end

		// we can now get our result
		#(`HALF_CYCLE*2)
			address = ADDR_RESULT;

		// start transmitting the result
		for (i = 0; i < 16; i = i + 1) begin
			#(`HALF_CYCLE*2);
			result_tmp[i] = data_out;
			// result[i*8+7:i*8] = data_out;
		end

		if(result != golden_256[0*15+0]) begin
			$display("fail the test: ");
			$display("the result is not consistent with gloden");
			$display("resukt: %h\ngolden: %h", result, golden_256[0*15+0]);
			err_count = err_count + 1;
		end


		$display("Pass all the tests.");

		$finish;

	end // initial begin

endmodule
