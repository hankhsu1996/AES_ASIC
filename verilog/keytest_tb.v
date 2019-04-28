`include "keytotal.v"
`timescale 1ns/1ps
`define HALF_CYCLE 1
`define TEST_LEN 11

module AES_core_tb ();

	reg    clk, rst_n;
	reg  [127:0]key    ;
	reg  [3:0] times;
	wire [127:0] keyout;

	reg [127:0] mem_data[0:`TEST_LEN-1];
	reg [3:0] mem_key[0:`TEST_LEN-1];
	reg [127:0] golden  [0:`TEST_LEN-1];

	integer i, err_count;

	// generate clock
	always #(`HALF_CYCLE) clk = ~clk;

	Keytotal a1(
		.clk      (clk   ),
		.rst_n    (rst_n),
		.times     (times),
		.key    (key   ),
		.keyout (keyout)
	);

	// read from file
	initial begin
		$readmemh("./inputkey.txt", mem_data);
		$readmemb("./rc.txt", mem_key);
		$readmemh("./outputkey.txt", golden);
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
				key <= mem_data[i];
				times <= mem_key[i];
			end

			@(negedge clk) begin
				$display("testing: addRoundKey",);
				$display("key:     %h\ntimes:       %h\nkeyout: %h\ngloden:    %h\n", key, times, keyout, golden[i]);
				if (golden[i] !== keyout) begin
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