`include "KeyTotal.v"
`timescale 1ns/1ps
`define HALF_CYCLE 1
`define TEST_LEN 100

module tb_KeyTotal_hank ();

	reg clk, rst_n;

	reg  [  3:0] round ;
	reg  [127:0] key   ;
	wire [127:0] keyout;

	reg [127:0] mem_key[0:`TEST_LEN*11-1];

	integer i, j, err_count;

	// generate clock
	always #(`HALF_CYCLE) clk = ~clk;

	KeyTotal keyTotal (
		.clk   (clk   ),
		.rst_n (rst_n ),
		.times (round ),
		.key   (key   ),
		.keyout(keyout)
	);

	// read from file
	initial begin
		$readmemh("./DAT/data_keyGen128.txt", mem_key);
	end

	// initialization
	initial begin
		clk = 1'b1;
		rst_n = 1'b1;

		@(posedge clk)
			rst_n <= 1'b0;

		err_count = 0;
		for (i = 0; i < `TEST_LEN; i = i + 1) begin
			round = 4'b0;
			@(posedge clk) begin
				rst_n <= 1'b1;
				key <= mem_key[i*11];
				$display("testing key generation:");
				$display("input key: %h", key);
			end

			for (j = 0; j < 10; j = j + 1) begin

				@(posedge clk) begin
					round = round + 1;
				end

				@(negedge clk) begin
					$display("keyout: %h", keyout);
					if (keyout != mem_key[i*11+round]) begin
						err_count = err_count + 1;
					end
				end
			end
		end // for loop

		if (err_count != 0) begin
			$display("error count: %d", err_count);
		end else begin
			$display("pass all the tests");
		end

		$finish;
	end

endmodule // tb_AES_encipher