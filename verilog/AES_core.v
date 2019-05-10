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
	output         result_valid  // encipher / decipher ready
);

	// ------------------------------------------------------
	// ------------------- all parameters -------------------
	// ------------------------------------------------------

	// define control state
	localparam CTRL_IDLE = 2'h0;
	localparam CTRL_INIT = 2'h1;
	localparam CTRL_NEXT = 2'h2;

	// registers
	reg [1:0] main_ctrl_reg;
	reg [1:0] main_ctrl_new;

	reg ready_reg;
	reg ready_new;

	reg result_valid_reg;
	reg result_valid_new;


	// key memory wires
	wire [127:0] round_key;
	wire         key_ready;

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
	assign ready        = ready_reg;
	assign result       = muxed_new_block;
	assign result_valid = result_valid_reg;

	// ------------------------------------------------------
	// --------------------- reg update ---------------------
	// ------------------------------------------------------


	always @(posedge clk or negedge rst_n) begin : always_async
		if(~rst_n) begin
			main_ctrl_reg    <= 2'b0;
			ready_reg        <= 1'b0;
			result_valid_reg <= 1'b0;
		end else begin
			main_ctrl_reg    <= main_ctrl_new;
			ready_reg        <= ready_new;
			result_valid_reg <= result_valid_new;
			$display("in core, key in:   %h", key[255:128]);
			$display("in core, block in: %h", block);
		end
	end


	// ------------------------------------------------------
	// ------------------ main controller  ------------------
	// ------------------------------------------------------

	always @(*) begin : main_ctrl

		// default assignments
		main_ctrl_new    = CTRL_IDLE;
		ready_new        = 1'b0;
		result_valid_new = 1'b0;

		case (main_ctrl_reg)

			CTRL_IDLE : begin
				if (init) begin
					main_ctrl_new = CTRL_INIT;
				end else if (next) begin
					main_ctrl_new = CTRL_NEXT;
				end
			end

			CTRL_INIT : begin
				if (key_ready) begin
					main_ctrl_new = CTRL_IDLE;
					ready_new     = 1'b1;
				end else begin
					main_ctrl_new = CTRL_INIT;
				end
			end

			CTRL_NEXT : begin
				if (muxed_ready) begin
					main_ctrl_new    = CTRL_IDLE;
					result_valid_new = 1'b1;
				end else begin
					main_ctrl_new    = CTRL_NEXT;
				end
			end

			default : begin end
		endcase // main_ctrl_reg
	end


	// ------------------------------------------------------
	// -------------------- multiplexer  --------------------
	// ------------------------------------------------------
	always @(*) begin : multiplexer
		if (encdec) begin
			enc_next        = next;
			muxed_new_block = enc_new_block;
			muxed_round     = enc_round;
			muxed_ready     = enc_ready;
		end else begin
			dec_next        = next;
			muxed_new_block = dec_new_block;
			muxed_round     = dec_round;
			muxed_ready     = dec_ready;
		end
	end

endmodule