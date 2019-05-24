`include "AES.v"
`timescale 1ns/1ps
`define HALF_CYCLE 10
`define TEST_LEN_128 100
`define TEST_LEN_256 100

module tb_AES ();

	// address
	localparam ADDR_IDLE = 4'h0;

	localparam ADDR_CONFIG       = 4'h1;
	localparam CONFIG_ENCDEC_BIT = 0   ;
	localparam CONFIG_KEYLEN_BIT = 1   ;

	localparam ADDR_KEY = 4'h2;

	localparam ADDR_BLOCK = 4'h3;

	localparam ADDR_STATUS      = 4'h5;
	localparam STATUS_READY_BIT = 0   ;
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

	reg  [127:0] key         ;
	wire [ 15:0] key_tmp[7:0];
	assign key_tmp[0] = key[16*8-1:16*7];
	assign key_tmp[1] = key[16*7-1:16*6];
	assign key_tmp[2] = key[16*6-1:16*5];
	assign key_tmp[3] = key[16*5-1:16*4];
	assign key_tmp[4] = key[16*4-1:16*3];
	assign key_tmp[5] = key[16*3-1:16*2];
	assign key_tmp[6] = key[16*2-1:16*1];
	assign key_tmp[7] = key[16*1-1:16*0];

	integer i, j, while_count, err_count;


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
	// initial begin
	// 	$fsdbDumpfile("AES.fsdb");

	// 	// 0: all, 1: this layer, 2: this and next layer
	// 	$fsdbDumpvars(2, tb_AES);

	// 	// if the data is 2D
	// 	$fsdbDumpMDA;
	// end

	// read from file
	initial begin
		$readmemh("../verilog/DAT/data_AES128_core.txt", mem_block_128);
		$readmemh("../verilog/DAT/data_keyGen128.txt", mem_key_128);
		$readmemh("../verilog/DAT/golden_AES128_core.txt", golden_128);
		$readmemh("../verilog/DAT/data_AES256_core.txt", mem_block_256);
		$readmemh("../verilog/DAT/data_keyGen256.txt", mem_key_256);
		$readmemh("../verilog/DAT/golden_AES256_core.txt", golden_256);
	end

	initial begin
		clk = 1'b1;
		rst_n = 1'b1;
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


		// -----------------------------------
		// -------- AES128 encryption --------
		// -----------------------------------

		$display("Testing AES128 encryption");
		address = 4'b0;
		data_in = 16'b0;


		// start to configure. check the congiguration result
		// be careful that when we use the CTRL_START to check the configuration, we should pull down the data_in
		address = ADDR_CONFIG;
		data_in[CONFIG_ENCDEC_BIT] = 1; // enc
		data_in[CONFIG_KEYLEN_BIT] = 0; // 128

		#(`HALF_CYCLE*20);
		address = ADDR_START;
		data_in = 16'b0;

		#(`HALF_CYCLE*2)
			address = ADDR_IDLE;
		if (data_out != {8'b00000100}) begin
			$display("fail the test: ");
			$display("After configuring, the data_out should be %8b but the actual data_out is %8b", 8'b00000100, data_out);
			err_count = err_count + 1;
		end

		// new encdec is set to 1, and keylen is set to 0 (AES128 encryption)
		// we can now start to input the key

		for (i = 0; i < `TEST_LEN_128; i = i + 1) begin

			#(`HALF_CYCLE*2);
			address = ADDR_KEY;

			// wait util the next clk because of the state machine mechanism
			key = mem_key_128[i*11];
			for (j = 0; j < 8; j = j + 1) begin
				#(`HALF_CYCLE*2);
				address = ADDR_IDLE;
				data_in = key_tmp[j];
			end

			// after inputing the key, change the address to START
			#(`HALF_CYCLE*2);
			address = ADDR_START;
			data_in = 16'b0;
			data_in[START_INIT_BIT] = 1;

			// FSM changes to start state, set init to start the key generation1
			#(`HALF_CYCLE*2);
			address = ADDR_STATUS;
			data_in = 16'b0;
			data_in[STATUS_READY_BIT] = 1;

			// wait until the data_out[ready] is pulled up to 1
			#(`HALF_CYCLE*2);
			while_count = 0;
			while (data_out != 8'h01) begin
				while_count = while_count + 1;
				@(negedge clk)
					data_in = 16'b0;
				if (while_count > 25) begin
					$display("infinite loop in AES128 encryption: key generation. exit simulaton with error.",);
					$finish;
				end
			end

			// prepare to input the block
			#(`HALF_CYCLE*2);
			address = ADDR_BLOCK;

			block = mem_block_128[i];
			for (j = 0; j < 8; j = j + 1) begin
				#(`HALF_CYCLE*2);
				address = ADDR_IDLE;
				data_in = block_tmp[j];
			end

			// after last round, start the encipher
			#(`HALF_CYCLE*2);
			address = ADDR_START;
			data_in = 16'b0;
			data_in[START_NEXT_BIT] = 1;

			#(`HALF_CYCLE*2);
			address = ADDR_STATUS;

			// wait until the data_out[valid] is pulled up to 1
			#(`HALF_CYCLE*2);
			while_count = 0;
			while (data_out != 8'h02) begin
				while_count = while_count + 1;
				@(negedge clk)
					data_in = 16'b0;
				if (while_count > 25) begin
					$display("infinite loop in AES128 encryption: main algorithm. exit simulaton with error.",);
					$finish;
				end
			end

			// we can now get our result
			#(`HALF_CYCLE*2);
			address = ADDR_RESULT;

			// start transmitting the result
			for (j = 0; j < 16; j = j + 1) begin
				#(`HALF_CYCLE*2);
				address = ADDR_IDLE;
				result_tmp[j] = data_out;
			end
			#(`HALF_CYCLE*2);

			if (result != golden_128[i]) begin
				$display("fail the test in AES128 encryption: ");
				$display("the result is not consistent with gloden");
				$display("key:    %h\nblock:  %h", key, block);
				$display("result: %h\ngolden: %h\n", result, golden_128[i]);
				err_count = err_count + 1;
			end
		end

		// -----------------------------------
		// -------- AES128 decryption --------
		// -----------------------------------

		$display("Testing AES128 decryption");
		address = 4'b0;
		data_in = 16'b0;


		// start to configure. check the congiguration result
		// be careful that when we use the CTRL_START to check the configuration, we should pull down the data_in
		address = ADDR_CONFIG;
		data_in[CONFIG_ENCDEC_BIT] = 0; // dec
		data_in[CONFIG_KEYLEN_BIT] = 0; // 128

		#(`HALF_CYCLE*20);
		address = ADDR_START;
		data_in = 16'b0;

		#(`HALF_CYCLE*2)
			address = ADDR_IDLE;
		if (data_out != {8'b00000000}) begin
			$display("fail the test: ");
			$display("After configuring, the data_out should be %8b but the actual data_out is %8b", 8'b00000000, data_out);
			err_count = err_count + 1;
		end

		// new encdec is set to 0, and keylen is set to 0 (AES128 decryption)
		// we can now start to input the key

		for (i = 0; i < `TEST_LEN_128; i = i + 1) begin

			#(`HALF_CYCLE*2);
			address = ADDR_KEY;

			// wait util the next clk because of the state machine mechanism
			key = mem_key_128[i*11];
			for (j = 0; j < 8; j = j + 1) begin
				#(`HALF_CYCLE*2);
				address = ADDR_IDLE;
				data_in = key_tmp[j];
			end

			// after inputing the key, change the address to START
			#(`HALF_CYCLE*2);
			address = ADDR_START;
			data_in = 16'b0;
			data_in[START_INIT_BIT] = 1;

			// FSM changes to start state, set init to start the key generation
			#(`HALF_CYCLE*2);
			address = ADDR_STATUS;
			data_in = 16'b0;
			data_in[STATUS_READY_BIT] = 1;

			// wait until the data_out[ready] is pulled up to 1
			#(`HALF_CYCLE*2);
			while_count = 0;
			while (data_out != 8'h01) begin
				while_count = while_count + 1;
				@(negedge clk)
					data_in = 16'b0;
				if (while_count > 25) begin
					$display("infinite loop in AES128 decryption: key generation. exit simulaton with error.",);
					$finish;
				end
			end

			// prepare to input the block
			#(`HALF_CYCLE*2);
			address = ADDR_BLOCK;

			block = golden_128[i];
			for (j = 0; j < 8; j = j + 1) begin
				#(`HALF_CYCLE*2);
				address = ADDR_IDLE;
				data_in = block_tmp[j];
			end

			// after last round, start the decipher
			#(`HALF_CYCLE*2);
			address = ADDR_START;
			data_in = 16'b0;
			data_in[START_NEXT_BIT] = 1;

			#(`HALF_CYCLE*2);
			// now is in the start state. The output will be {4'b0, keylen, encdec, next, init}
			// be careful! This is not the status output
			address = ADDR_STATUS;

			// wait until the data_out[valid] is pulled up to 1
			#(`HALF_CYCLE*2);
			while_count = 0;
			while (data_out != 8'h02) begin
				while_count = while_count + 1;
				@(negedge clk)
					data_in = 16'b0;
				if (while_count > 25) begin
					$display("infinite loop in AES128 decryption: main algorithm. exit simulaton with error.",);
					$finish;
				end
			end

			// we can now get our result
			#(`HALF_CYCLE*2);
			address = ADDR_RESULT;

			// start transmitting the result
			for (j = 0; j < 16; j = j + 1) begin
				#(`HALF_CYCLE*2);
				address = ADDR_IDLE;
				result_tmp[j] = data_out;
			end
			#(`HALF_CYCLE*2);

			if (result != mem_block_128[i]) begin
				$display("fail the test in AES128 decryption: ");
				$display("the result is not consistent with gloden");
				$display("key:    %h\nblock:  %h", key, block);
				$display("result: %h\ngolden: %h\n", result, mem_block_128[i]);
				err_count = err_count + 1;
			end
		end


		// -----------------------------------
		// -------- AES256 encryption --------
		// -----------------------------------

		$display("Testing AES256 encryption");
		address = 4'b0;
		data_in = 16'b0;

		// start to configure. check the congiguration result
		// be careful that when we use the CTRL_START to check the configuration, we should pull down the data_in
		#(`HALF_CYCLE*20);
		address = ADDR_CONFIG;
		data_in[CONFIG_ENCDEC_BIT] = 1; // enc
		data_in[CONFIG_KEYLEN_BIT] = 1; // 256

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
		for (i = 0; i < `TEST_LEN_256; i = i + 1) begin

			#(`HALF_CYCLE*2);
			address = ADDR_KEY;

			// wait util the next clk because of the state machine mechanism
			key = mem_key_256[i*15+0];
			for (j = 0; j < 8; j = j + 1) begin
				#(`HALF_CYCLE*2);
				address = ADDR_IDLE;
				data_in = key_tmp[j];
			end

			key = mem_key_256[i*15+1];
			for (j = 0; j < 8; j = j + 1) begin
				#(`HALF_CYCLE*2);
				address = ADDR_IDLE;
				data_in = key_tmp[j];
			end

			// after inputing the key, change the address to START
			#(`HALF_CYCLE*2);
			address = ADDR_START;
			data_in = 16'b0;
			data_in[START_INIT_BIT] = 1;

			// FSM changes to start state, set init to start the key generation1
			#(`HALF_CYCLE*2);
			address = ADDR_STATUS;
			data_in = 16'b0;
			data_in[STATUS_READY_BIT] = 1;

			// wait until the data_out[ready] is pulled up to 1
			#(`HALF_CYCLE*2);
			while_count = 0;
			while (data_out != 8'h01) begin
				while_count = while_count + 1;
				@(negedge clk)
					data_in = 16'b0;
				if (while_count > 25) begin
					$display("infinite loop in AES256 encryption: key generation. exit simulaton with error.",);
					$finish;
				end
			end

			// prepare to input the block
			#(`HALF_CYCLE*2);
			address = ADDR_BLOCK;

			block = mem_block_256[i];
			for (j = 0; j < 8; j = j + 1) begin
				#(`HALF_CYCLE*2);
				address = ADDR_IDLE;
				data_in = block_tmp[j];
			end

			// after last round, start the encipher
			#(`HALF_CYCLE*2);
			address = ADDR_START;
			data_in = 16'b0;
			data_in[START_NEXT_BIT] = 1;

			#(`HALF_CYCLE*2);
			address = ADDR_STATUS;

			// wait until the data_out[valid] is pulled up to 1
			#(`HALF_CYCLE*2);
			while_count = 0;
			while (data_out != 8'h02) begin
				while_count = while_count + 1;
				@(negedge clk)
					data_in = 16'b0;
				if (while_count > 25) begin
					$display("infinite loop in AES256 encryption: main algorithm. exit simulaton with error.",);
					$finish;
				end
			end

			// we can now get our result
			#(`HALF_CYCLE*2);
			address = ADDR_RESULT;

			// start transmitting the result
			for (j = 0; j < 16; j = j + 1) begin
				#(`HALF_CYCLE*2);
				address = ADDR_IDLE;
				result_tmp[j] = data_out;
			end
			#(`HALF_CYCLE*2);

			if (result != golden_256[i]) begin
				$display("fail the test in AES256 encryption: ");
				$display("the result is not consistent with gloden");
				$display("key:    %h\nblock:  %h", key, block);
				$display("result: %h\ngolden: %h\n", result, golden_256[i]);
				err_count = err_count + 1;
			end
		end


		// -----------------------------------
		// -------- AES256 decryption --------
		// -----------------------------------

		$display("Testing AES256 decryption");
		address = 4'b0;
		data_in = 16'b0;


		// start to configure. check the congiguration result
		// be careful that when we use the CTRL_START to check the configuration, we should pull down the data_in
		address = ADDR_CONFIG;
		data_in[CONFIG_ENCDEC_BIT] = 0; // dec
		data_in[CONFIG_KEYLEN_BIT] = 1; // 256

		#(`HALF_CYCLE*20);
		address = ADDR_START;
		data_in = 16'b0;

		#(`HALF_CYCLE*2)
			address = ADDR_IDLE;
		if (data_out != {8'b00001000}) begin
			$display("fail the test: ");
			$display("After configuring, the data_out should be %8b but the actual data_out is %8b", 8'b00001000, data_out);
			err_count = err_count + 1;
		end

		// new encdec is set to 0, and keylen is set to 0 (AES256 decryption)
		// we can now start to input the key

		for (i = 0; i < `TEST_LEN_256; i = i + 1) begin

			#(`HALF_CYCLE*2);
			address = ADDR_KEY;

			// wait util the next clk because of the state machine mechanism
			key = mem_key_256[i*15];
			for (j = 0; j < 8; j = j + 1) begin
				#(`HALF_CYCLE*2);
				address = ADDR_IDLE;
				data_in = key_tmp[j];
			end

			key = mem_key_256[i*15+1];
			for (j = 0; j < 8; j = j + 1) begin
				#(`HALF_CYCLE*2);
				address = ADDR_IDLE;
				data_in = key_tmp[j];
			end

			// after inputing the key, change the address to START
			#(`HALF_CYCLE*2);
			address = ADDR_START;
			data_in = 16'b0;
			data_in[START_INIT_BIT] = 1;

			// FSM changes to start state, set init to start the key generation
			#(`HALF_CYCLE*2);
			address = ADDR_STATUS;
			data_in = 16'b0;
			data_in[STATUS_READY_BIT] = 1;

			// wait until the data_out[ready] is pulled up to 1
			#(`HALF_CYCLE*2);
			while_count = 0;
			while (data_out != 8'h01) begin
				while_count = while_count + 1;
				@(negedge clk)
					data_in = 16'b0;
				if (while_count > 25) begin
					$display("infinite loop in AES256 decryption: key generation. exit simulaton with error.",);
					$finish;
				end
			end

			// prepare to input the block
			#(`HALF_CYCLE*2);
			address = ADDR_BLOCK;

			block = golden_256[i];
			for (j = 0; j < 8; j = j + 1) begin
				#(`HALF_CYCLE*2);
				address = ADDR_IDLE;
				data_in = block_tmp[j];
			end

			// after last round, start the decipher
			#(`HALF_CYCLE*2);
			address = ADDR_START;
			data_in = 16'b0;
			data_in[START_NEXT_BIT] = 1;

			#(`HALF_CYCLE*2);
			// now is in the start state. The output will be {4'b0, keylen, encdec, next, init}
			// be careful! This is not the status output
			address = ADDR_STATUS;

			// wait until the data_out[valid] is pulled up to 1
			#(`HALF_CYCLE*2);
			while_count = 0;
			while (data_out != 8'h02) begin
				while_count = while_count + 1;
				@(negedge clk)
					data_in = 16'b0;
				if (while_count > 25) begin
					$display("infinite loop in AES256 decryption: main algorithm. exit simulaton with error.",);
					$finish;
				end
			end

			// we can now get our result
			#(`HALF_CYCLE*2);
			address = ADDR_RESULT;

			// start transmitting the result
			for (j = 0; j < 16; j = j + 1) begin
				#(`HALF_CYCLE*2);
				address = ADDR_IDLE;
				result_tmp[j] = data_out;
			end
			#(`HALF_CYCLE*2);

			if (result != mem_block_256[i]) begin
				$display("fail the test in AES256 decryption: ");
				$display("the result is not consistent with gloden");
				$display("key:    %h\nblock:  %h", key, block);
				$display("result: %h\ngolden: %h\n", result, mem_block_256[i]);
				err_count = err_count + 1;
			end
		end

		#(`HALF_CYCLE*20);
		if (err_count == 0) begin
			$display("Pass all the tests.");
		end else begin
			$display("There is error running the testbench. Please check the above information.",);
		end

		$finish;

	end // initial begin



endmodule
