`include "AES.v"
`timescale 1ns/1ps
`define HALF_CYCLE 1

module tb_AES ();

	// address
	localparam ADDR_CONFIG       = 4'h1;
	localparam CONFIG_ENCDEC_BIT = 0   ;
	localparam CONFIG_KEYLEN_BIT = 1   ;

	localparam ADDR_KEY = 4'h2;

	localparam ADDR_BLOCK = 4'h3;

	localparam ADDR_STATUS      = 4'h4;
	localparam STATUS_READY_BIT = 0   ; // not used.
	localparam STATUS_VALID_BIT = 1   ;

	localparam ADDR_START     = 4'hf;
	localparam START_INIT_BIT = 0   ;
	localparam START_NEXT_BIT = 1   ;

	localparam ADDR_RESULT = 4'h5;

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
		$dumpfile("AES_core.vcd");

		// 0: all, 1: this layer, 2: this and next layer
		$dumpvars(2, tb_AES_core);
	end

	// read from file
	initial begin
		// $readmemh("./DAT/data_AES128_core.txt", mem_block_128);
		// $readmemh("./DAT/data_keyGen128.txt", mem_key_128);
		// $readmemh("./DAT/golden_AES128_core.txt", golden_128);
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

		@(negedge clk)
			rst_n = 1'b0;

		@(negedge clk) begin
			// in the first clock, pull init to 1'b1
			// the key_mem will automatically start
			rst_n = 1'b1;
			init = 1'b1;
			next = 1'b0;
			key = {mem_key_128[i * 11], 128'b0};
			block = mem_block_128[i];
		end

		// key_mem keep generate round keys
		// when finishing, break from loop
		while (ready == 1'b0) begin
			@(negedge clk) begin
				init = 1'b0;
			end
		end


		// finished generate keys.
		// start the encipher / decipher
		@(negedge clk) begin
			next = 1'b1;
		end

		// automatically start encrypt / decrypt
		// when finishing, break from loop
		while (result_valid == 1'b0) begin
			@(negedge clk) begin
				next = 1'b0;
			end
		end

		// now the result should have been calculated
		// at negedge, evaluate the result and count the error
		@(negedge clk) begin
			$display("key in:    %h", key);
			$display("block in:  %h", block);
			$display("block out: %h", result);
			$display("golden:    %h\n", golden_128[i]);

			// count error
			if (result !== golden_128[i]) begin
				err_count_enc_128 = err_count_enc_128 + 1;
			end
		end


		$finish;

	end // initial begin

endmodule
