`include "constant.v"

module AES_core (
    input          clk      , // Clock
    input          rst_n    , // Asynchronous reset active low
    input  [127:0] round_key,
    input  [127:0] block    ,
    output [127:0] new_block
);

    function [7:0] lookupE (input [7:0] block);
        lookupE = constant.E[block];
    endfunction

    function [7:0] lookupL (input [7:0] block);
        lookupL = constant.L[block];
    endfunction

    function [7:0] add(input [7:0] a, input [7:0] b);
        reg [8:0] temp;
        begin
            temp = a + b;

            if (temp > 8'hff) begin
                temp = temp - 8'hff;
            end

            add[7:0] = temp[7:0];
        end
    endfunction

    function [7:0] lookupEL(input [7:0] block, input [7:0] constant);
        if (block == 8'h00) begin
            lookupEL = 8'h00;
        end else begin
            lookupEL = lookupE(add(lookupL(block), lookupL(constant)));
        end
    endfunction

    function [31:0] inv_mixColumn32(input [31:0] block);
        begin
            inv_mixColumn32[31:24] = lookupEL(block[7:0], 8'h09) ^ lookupEL(block[15:8], 8'h0d) ^ lookupEL(block[23:16], 8'h0b) ^ lookupEL(block[31:24], 8'h0e);
            inv_mixColumn32[23:16] = lookupEL(block[7:0], 8'h0d) ^ lookupEL(block[15:8], 8'h0b) ^ lookupEL(block[23:16], 8'h0e) ^ lookupEL(block[31:24], 8'h09);
            inv_mixColumn32[15: 8] = lookupEL(block[7:0], 8'h0b) ^ lookupEL(block[15:8], 8'h0e) ^ lookupEL(block[23:16], 8'h09) ^ lookupEL(block[31:24], 8'h0d);
            inv_mixColumn32[ 7: 0] = lookupEL(block[7:0], 8'h0e) ^ lookupEL(block[15:8], 8'h09) ^ lookupEL(block[23:16], 8'h0d) ^ lookupEL(block[31:24], 8'h0b);

        end
    endfunction

    function [127:0] inv_mixColumn (input [127:0] block);
        begin
            inv_mixColumn[31:0] = inv_mixColumn32(block[31:0]);
            inv_mixColumn[63:32] = inv_mixColumn32(block[63:32]);
            inv_mixColumn[95:64] = inv_mixColumn32(block[95:64]);
            inv_mixColumn[127:96] = inv_mixColumn32(block[127:96]);
        end
    endfunction

    assign new_block = inv_mixColumn(block);

endmodule




