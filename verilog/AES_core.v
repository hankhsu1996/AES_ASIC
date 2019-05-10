`include "AES_encipher.v"
`include "AES_decipher.v"
`include "AES_key_mem_seq.v"

module AES_core (
	input          clk         , // Clock
	input          rst_n       , // Asynchronous reset active low
	input          encdec      , // Encipher or decipher
	input          init        , // call key_mem to start
	input          next        , // call encipher / decipher to start
	output         ready       , // key_mem ready
	input  [255:0] key         ,
	input          keylen      , // AES128 or AES256
	input  [127:0] block       ,
	output [127:0] result      ,
	output         result_valid // encipher / decipher ready
);

	// ------------------------------------------------------
	// ------------------- all parameters -------------------
	// ------------------------------------------------------

	// define control state
	localparam CTRL_IDLE = 2'h0;
	localparam CTRL_INIT = 2'h1;
	localparam CTRL_NEXT = 2'h2;

	// registers
	reg aes_core_ctrl_reg;
	reg aes_core_ctrl_new;

	reg ready_reg;
	reg ready_new;

	reg result_valid_reg;
	reg result_valid_new;


	// key memory wires
	wire [127:0] round_key;
	wire key_ready;

	// enc wires
	reg          enc_next     ;
	wire [  3:0] enc_round    ;
	wire [127:0] enc_new_block;
	wire         enc_ready    ;

	// dec wires
	reg          dec_next     ;
	wire [  3:0] dec_round    ;
	wire [127:0] dec_new_block;
	wire         dec_ready    ;

	// for MUX
	reg [127:0] muxed_new_block;
	reg [  3:0] muxed_round    ;
	reg         muxed_ready    ;

	// ------------------------------------------------------
	// ------------------- instanciation --------------------
	// ------------------------------------------------------
	AES_encipher enc (
		.clk      (clk          ),
		.rst_n    (rst_n        ),
		.next     (enc_next     ),
		.keylen   (keylen       ),
		.round    (enc_round    ),
		.round_key(round_key    ),
		.block    (block        ),
		.new_block(enc_new_block),
		.ready    (enc_ready    )
	);

	AES_decipher dec (
		.clk      (clk          ),
		.rst_n    (rst_n        ),
		.next     (dec_next     ),
		.keylen   (keylen       ),
		.round    (dec_round    ),
		.round_key(round_key    ),
		.block    (block        ),
		.new_block(dec_new_block),
		.ready    (dec_ready    )
	);

	AES_key_mem_seq key_mem (
		.clk      (clk        ),
		.rst_n    (rst_n      ),
		.key      (key        ),
		.keylen   (keylen     ),
		.init     (init       ),
		.round    (muxed_round),
		.round_key(round_key  ),
		.ready    (key_ready  )
	);

	// Concurrent connectivity for ports
    assign ready     = ready_reg;
    assign  result    = muxed_new_block;
    assign result_valid = result_valid_reg;

	// ------------------------------------------------------
	// --------------------- reg update ---------------------
	// ------------------------------------------------------



endmodule