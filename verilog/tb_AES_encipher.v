`include "AES_encipher.v"
`timescale 1ns/1ps
`define HALF_CYCLE 1
`define TEST_LEN 2

module tb_AES_encipher ();

	reg clk, rst_n;

	reg  next  ; // indicate begin
	reg  keylen; // indicate AES128 or AES256
	wire round ; // output of AES_encipher to determine which key we'll use

	reg  [127:0] round_key; // main input
	reg  [127:0] block    ; // main input
	wire [127:0] new_block; // main output

	wire ready; // indicate state machine go to finish

	reg [127:0] mem_block[0:`TEST_LEN-1];
	reg [127:0] mem_round_key[0:`TEST_LEN-1];
	reg [127:0] golden  [0:`TEST_LEN-1];

	integer i, err_count;

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
		@(posedge clk)
			rst_n <= 1'b0;

		err_count = 0;
		for (i = 0; i < `TEST_LEN; i = i + 1) begin
			@(posedge clk) begin
				rst_n <= 1'b1;
				block <= mem_data[i];
				round_key <= mem_key[i];
			end

			@(negedge clk) begin
				$display("testing: addRoundKey",);
				$display("block:     %h\nkey:       %h\nnew_block: %h\ngloden:    %h\n", block, round_key, new_block, golden[i]);
				if (golden[i] !== new_block) begin
					err_count = err_count + 1;
				end
			end
		end

		if (err_count != 0) begin
			$display("error count: %d", err_count);
		end else begin
			$display("pass all the tests");
		end

		$finish;
	end
endmodule

endmodule // tb_AES_encipher