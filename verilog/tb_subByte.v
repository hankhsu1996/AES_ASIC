`include "subByte.v"
`timescale 1ns/1ps
`define HALF_CYCLE 1
`define TEST_LEN 10

module AES_core_tb;

	reg          clk, rst_n;
	reg  [127:0] block  ;
	wire [127:0] new_block;

	reg [127:0] mem_data[0:`TEST_LEN-1];
	reg [127:0] golden  [0:`TEST_LEN-1];

	integer i, err_count;

	// generate clock
	always #(`HALF_CYCLE) clk = ~clk;

	AES_core aes_core (
		.clk   (clk   ),
		.rst_n (rst_n ),
		.block  (block  ),
		.new_block(new_block)
	);

	// read from file
	initial begin
		$readmemh("./DAT/data_subByte.txt", mem_data);
		$readmemh("./DAT/golden_subByte.txt", golden);
	end

	// initialization
	initial begin
		clk = 1'b1;
		rst_n = 1'b1;
		@(posedge clk)
			rst_n<= 1'b0;

		err_count = 0;
		for (i = 0; i < `TEST_LEN; i = i + 1) begin
			@(posedge clk) begin
				rst_n <= 1'b1;
				block <= mem_data[i];
			end

			@(negedge clk) begin
				$display("testing: subByte",);
				$display("block:     %h\nnew_block: %h\ngloden:    %h\n", block, new_block, golden[i]);
				if (golden[i] !== new_block) begin
					err_count++;
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