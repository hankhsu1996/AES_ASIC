`include "AES_encipher.v"
`timescale 1ns/1ps
`define HALF_CYCLE 1
`define TEST_LEN 100

module tb_AES_encipher ();

	reg clk, rst_n;

	reg        next  ; // indicate begin
	reg        keylen; // indicate AES128 or AES256
	wire [3:0] round ; // output of AES_encipher to determine which key we'll use

	reg  [127:0] round_key; // main input
	reg  [127:0] block    ; // main input
	wire [127:0] new_block; // main output

	wire ready; // indicate state machine go to finish

	reg [127:0] mem_block    [   0:`TEST_LEN-1];
	reg [127:0] mem_round_key[0:`TEST_LEN*11-1];
	reg [127:0] golden       [   0:`TEST_LEN-1];

	integer i, counter, err_count;

	// generate clock
	always #(`HALF_CYCLE) clk = ~clk;

	AES_encipher AES_encipher (
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
		$readmemh("./DAT/data_AES_encipher.txt", mem_block);
		$readmemh("./DAT/data_keyGen128.txt", mem_round_key);
		$readmemh("./DAT/golden_AES_encipher.txt", golden);
	end

	// initialization
	initial begin
		clk = 1'b1;
		rst_n = 1'b1;
		keylen = 1'h0; // AES128

		@(posedge clk)
			rst_n <= 1'b0;

		err_count = 0;
		for (i = 0; i < `TEST_LEN; i = i + 1) begin
			@(posedge clk) begin
				rst_n <= 1'b1;
				block <= mem_block[i];
				next <= 1'b1;
				counter = 0;
			end

			while (ready == 1'b0) begin
				@(posedge clk) begin
					next = 1'b0;
					case (counter)
						0: begin round_key = mem_round_key[i*11]; end
						1: begin round_key = mem_round_key[i*11+1]; end
						2: begin round_key = mem_round_key[i*11+2]; end
						3: begin round_key = mem_round_key[i*11+3]; end
						4: begin round_key = mem_round_key[i*11+4]; end
						5: begin round_key = mem_round_key[i*11+5]; end
						6: begin round_key = mem_round_key[i*11+6]; end
						7: begin round_key = mem_round_key[i*11+7]; end
						8: begin round_key = mem_round_key[i*11+8]; end
						9: begin round_key = mem_round_key[i*11+9]; end
						10: begin round_key = mem_round_key[i*11+10]; end
					endcase // counter
				end

				@(negedge clk) begin
					if (counter == 0) begin
						$display("start testing encipher.\nin the initial round:\nblock in: %h\nkey in:   %h\n", block, round_key);
					end else begin
						$display("in round %d:", round);
						$display("key in:    %h\nblock out: %h\nready: %b\n", round_key, new_block, ready);
					end

				end
				counter = counter + 1;
			end

			// the encipher is ready
			@(negedge clk) begin : count_err
				$display("result: %h\n", new_block);
				if (golden[i] !== new_block) begin
					err_count = err_count + 1;
				end
			end // count_err

			// #(`HALF_CYCLE*4);
		end // for loop

		if (err_count != 0) begin
			$display("error count: %d", err_count);
		end else begin
			$display("pass all the tests");
		end

		$finish;
	end

endmodule // tb_AES_encipher