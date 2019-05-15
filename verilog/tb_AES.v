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

	integer err_count;


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
	end

	// define some tasks
	task write_addr(input [3:0] addr);
		@(negedge clk) begin
			address = addr;
		end
	endtask

	task write_data(input [15:0] data);
		@(negedge clk) begin
			data_in = data;
		end
	endtask

	task read_data(output [7:0] data);
		@(negedge clk) begin
			data = data_out;
		end
	endtask

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
		write_data(16'habcd);
		if (data_out != 8'b0) begin
			$display("fail the test: ");
			$display("With messy data_in, the data_out should be %8b but the actual data_out is %8b", 8'b0, data_out);
			err_count = err_count + 1;
		end

		// check the value of keylen, encdec, next, init before configuration
		write_addr(ADDR_START);
		if (data_out != 8'b0) begin
			$display("fail the test: ");
			$display("With messy data_in, the data_out should be %8b but the actual data_out is %8b", 8'b0, data_out);
			err_count = err_count + 1;
		end

		// start to configure. check the congiguration result 
		// be careful that when we use the CTRL_START to check the configuration, we should pull down the data_in  
		write_addr(ADDR_CONFIG);
		data_in[CONFIG_ENCDEC_BIT] = 1;
		data_in[CONFIG_KEYLEN_BIT] = 1;
		
		write_addr(ADDR_START);
		#(`HALF_CYCLE*2)
		data_in[START_INIT_BIT] = 0;
		data_in[START_NEXT_BIT] = 0;
		if (data_out != {8'b00001100}) begin
			$display("fail the test: ");
			$display("After configuring, the data_out should be %8b but the actual data_out is %8b", 8'b00001100, data_out);
			err_count = err_count + 1;
		end

		// new encdec is set to 1, and keylen is set to 1 (AES256 encryption)
		// we can now start to input the key



		#1000


		$display("Pass all the tests.");

		$finish;

	end // initial begin

endmodule
