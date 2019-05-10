`include "AES_core.v"
`timescale 1ns/1ps
`define HALF_CYCLE 1
`define TEST_LEN_128 100
`define TEST_LEN_256 1

module tb_AES_core ();

	reg clk, rst_n;
	reg encdec;
	reg init, next;

	wire ready, result_valid;

	reg          keylen;
	reg  [255:0] key   ;
	reg  [127:0] block ;
	wire [127:0] result;

	reg [127:0] mem_block_128[   0:`TEST_LEN_128-1];
	reg [127:0] mem_key_128  [0:`TEST_LEN_128*11-1];
	reg [127:0] golden_128   [   0:`TEST_LEN_128-1];

	integer i, err_count_128;

	// generate clock
	always #(`HALF_CYCLE) clk = ~clk;


	AES_core AES_core (
		.clk         (clk         ),
		.rst_n       (rst_n       ),
		.encdec      (encdec      ),
		.init        (init        ),
		.next        (next        ),
		.ready       (ready       ),
		.key         (key         ),
		.keylen      (keylen      ),
		.block       (block       ),
		.result      (result      ),
		.result_valid(result_valid)
	);


	// dump vars
	initial begin
		$dumpfile("AES_core.vcd");
		// 0: all, 1: this layer, 2: this and next layer
		$dumpvars(2, tb_AES_core);
	end


	// read from file
	initial begin
		$readmemh("./DAT/data_AES128_core.txt", mem_block_128);
		$readmemh("./DAT/data_keyGen128.txt", mem_key_128);
		$readmemh("./DAT/golden_AES128_core.txt", golden_128);
	end

	initial begin
		// AES 128 encryption
		clk = 1'b1;
		rst_n = 1'b1;
		encdec = 1'b1;
		init = 1'b0;
		next = 1'b0;
		keylen = 1'h0;

		@(negedge clk)
			rst_n = 1'b0;

		err_count_128 = 0;
		for (i = 0; i < `TEST_LEN_128; i = i + 1) begin
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
			@(posedge clk) begin
				next = 1'b1;
			end

			// automatically start encrypt / decrypt
			// when finishing, break from loop
			while (result_valid == 1'b0) begin
				@(posedge clk) begin
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
					err_count_128 = err_count_128 + 1;
				end
			end
		end // for loop


		if (err_count_128 != 0) begin
			$display("error count: %d for AES128", err_count_128);
		end else begin
			$display("pass all the tests for AES128");
		end

		$finish;

	end // initial begin

endmodule
