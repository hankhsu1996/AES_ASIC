`include "AES_encipher.v"

module AES_core (
	input          clk         , // Clock
	input          rst_n       , // Asynchronous reset active low
	input          encdec      , // Encipher or decipher
	input          init        ,
	input          next        ,
	output         ready       ,
	input  [255:0] key         ,
	input          keylen      , // AES128 or AES256
	input  [255:0] block       ,
	output [255:0] result      ,
	output         result_valid
);

	// ------------------------------------------------------
	// ------------------- all parameters -------------------
	// ------------------------------------------------------

	// define control state
	localparam CTRL_IDLE = 2'h0;
	localparam CTRL_INIT = 2'h1;
	localparam CTRL_NEXT = 2'h2;

	// key generation wires
	
	
	// enc wires
	reg enc_next;
	wire [3:0] enc_round;
	wire [127:0] enc_new_block;
	wire enc_ready; 


	// ------------------------------------------------------
	// ------------------- instanciation --------------------
	// ------------------------------------------------------
	AES_encipher enc(
		.clk      (clk),
		.rst_n    (rst_n),
		.next     (enc_next),
		.keylen   (keylen),
		.round    (enc_round),
		.round_key(round_key),
		.block    (block),
		.new_block(enc_new_block),
		.ready    (enc_ready)
	);

	// ------------------------------------------------------
    // --------------------- reg update ---------------------
    // ------------------------------------------------------


endmodule