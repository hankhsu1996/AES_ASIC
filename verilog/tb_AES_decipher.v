`include "AES_decipher.v"
`timescale 1ns/1ps
`define HALF_CYCLE 1
`define TEST_LEN_128 1
`define TEST_LEN_256 1

module tb_AES_decipher ();

	reg clk, rst_n;

	reg        next  ; // indicate begin
	reg        keylen; // indicate AES128 or AES256
	wire [3:0] round ; // output of AES_decipher to determine which key we'll use

	reg  [127:0] round_key; // main input
	reg  [127:0] block    ; // main input
	wire [127:0] new_block; // main output

	wire ready; // indicate state machine go to finish

	reg [127:0] mem_block_128    [   0:`TEST_LEN_128-1];
	reg [127:0] mem_round_key_128[0:`TEST_LEN_128*11-1];
	reg [127:0] golden_128       [   0:`TEST_LEN_128-1];

	reg [127:0] mem_block_256    [   0:`TEST_LEN_256-1];
	reg [127:0] mem_round_key_256[0:`TEST_LEN_256*15-1];
	reg [127:0] golden_256       [   0:`TEST_LEN_256-1];

	integer i, counter, err_count_128, err_count_256;

	// generate clock
	always #(`HALF_CYCLE) clk = ~clk;

	AES_decipher AES_decipher (
		.clk      (clk      ),
		.rst_n    (rst_n    ),
		.next     (next     ),
		.keylen   (keylen   ),
		.round    (round    ),
		.round_key(round_key),
		.block    (block    ),
		.new_block(new_block),
		.ready    (ready    )
	);

	// read from file
	initial begin
		$readmemh("./DAT/data_AES128_decipher.txt", mem_block_128);
		$readmemh("./DAT/data_keyGen128.txt", mem_round_key_128);
		$readmemh("./DAT/golden_AES128_decipher.txt", golden_128);
		$readmemh("./DAT/data_AES256_decipher.txt", mem_block_256);
		$readmemh("./DAT/data_keyGen256.txt", mem_round_key_256);
		$readmemh("./DAT/golden_AES256_decipher.txt", golden_256);
	end

	initial begin

		// AES128
		clk = 1'b1;
		rst_n = 1'b1;
		keylen = 1'h0;

		@(posedge clk)
			rst_n <= 1'b0;

		err_count_128 = 0;
		for (i = 0; i < `TEST_LEN_128; i = i + 1) begin
			@(posedge clk) begin
				rst_n <= 1'b1;
				block <= mem_block_128[i];
				next <= 1'b1;
				counter = 10;
			end

			while (ready == 1'b0) begin
				@(posedge clk) begin
					next = 1'b0;
					case (counter)
						0: begin round_key = mem_round_key_128[i*11]; end
						1: begin round_key = mem_round_key_128[i*11+1]; end
						2: begin round_key = mem_round_key_128[i*11+2]; end
						3: begin round_key = mem_round_key_128[i*11+3]; end
						4: begin round_key = mem_round_key_128[i*11+4]; end
						5: begin round_key = mem_round_key_128[i*11+5]; end
						6: begin round_key = mem_round_key_128[i*11+6]; end
						7: begin round_key = mem_round_key_128[i*11+7]; end
						8: begin round_key = mem_round_key_128[i*11+8]; end
						9: begin round_key = mem_round_key_128[i*11+9]; end
						10: begin round_key = mem_round_key_128[i*11+10]; end
					endcase // counter
				end

				@(negedge clk) begin
					if (counter == 10) begin
						$display("start testing decipher.\nin the initial round:\nblock in: %h\nkey in:   %h\n", block, round_key);
					end else begin
						$display("in round %d:", round);
						$display("key in:    %h\nblock out: %h\nready: %b\n", round_key, new_block, ready);
					end

				end
				counter = counter - 1;
			end

			// the decipher is ready
			@(negedge clk) begin : count_err_128
				$display("result: %h\n", new_block);
				if (golden_128[i] !== new_block) begin
					err_count_128 = err_count_128 + 1;
				end
			end // count_err_128

		end // for loop

		




		// AES256
		clk = 1'b1;
		rst_n = 1'b1;
		keylen = 1'h1;

		@(posedge clk)
			rst_n <= 1'b0;

		err_count_256 = 0;
		for (i = 0; i < `TEST_LEN_256; i = i + 1) begin
			@(posedge clk) begin
				rst_n <= 1'b1;
				block <= mem_block_256[i];
				next <= 1'b1;
				counter = 14;
			end

			while (ready == 1'b0) begin
				@(posedge clk) begin
					next = 1'b0;
					case (counter)
						0: begin round_key = mem_round_key_256[i*15]; end
						1: begin round_key = mem_round_key_256[i*15+1]; end
						2: begin round_key = mem_round_key_256[i*15+2]; end
						3: begin round_key = mem_round_key_256[i*15+3]; end
						4: begin round_key = mem_round_key_256[i*15+4]; end
						5: begin round_key = mem_round_key_256[i*15+5]; end
						6: begin round_key = mem_round_key_256[i*15+6]; end
						7: begin round_key = mem_round_key_256[i*15+7]; end
						8: begin round_key = mem_round_key_256[i*15+8]; end
						9: begin round_key = mem_round_key_256[i*15+9]; end
						10: begin round_key = mem_round_key_256[i*15+10]; end
						11: begin round_key = mem_round_key_256[i*15+11]; end
						12: begin round_key = mem_round_key_256[i*15+12]; end
						13: begin round_key = mem_round_key_256[i*15+13]; end
						14: begin round_key = mem_round_key_256[i*15+14]; end
					endcase // counter
				end

				@(negedge clk) begin
					if (counter == 0) begin
						$display("start testing decipher.\nin the initial round:\nblock in: %h\nkey in:   %h\n", block, round_key);
					end else begin
						$display("in round %d:", round);
						$display("key in:    %h\nblock out: %h\nready: %b\n", round_key, new_block, ready);
					end

				end
				counter = counter - 1;
			end

			// the decipher is ready
			@(negedge clk) begin : count_err_256
				$display("result: %h\n", new_block);
				if (golden_256[i] !== new_block) begin
					err_count_256 = err_count_256 + 1;
				end
			end // count_err_256

		end // for loop

		


		if (err_count_128 != 0) begin
			$display("error count: %d for AES128", err_count_128);
		end else begin
			$display("pass all the tests for AES128");
		end

		if (err_count_256 != 0) begin
			$display("error count: %d for AES256", err_count_256);
		end else begin
			$display("pass all the tests for AES256");
		end

		$finish;
	end


endmodule // tb_AES_decipher