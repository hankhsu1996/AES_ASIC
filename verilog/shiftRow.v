`include "constant.v"

module AES_core (
    input          clk   , // Clock
    input          rst_n , // Asynchronous reset active low
    input  [127:0] block  ,
    output [127:0] new_block
);

    function [127:0] shiftRow(input [127:0] block);
        reg [127:0] temp;
        begin
            temp[8*0+7:8*0] = block[8*0+7:8*0];
            temp[8*1+7:8*1] = block[8*5+7:8*5];
            temp[8*2+7:8*2] = block[8*10+7:8*10];
            temp[8*3+7:8*3] = block[8*15+7:8*15];

            temp[8*4+7:8*4] = block[8*4+7:8*4];
            temp[8*5+7:8*5] = block[8*9+7:8*9];
            temp[8*6+7:8*6] = block[8*14+7:8*14];
            temp[8*7+7:8*7] = block[8*3+7:8*3];

            temp[8*8+7:8*8] = block[8*8+7:8*8];
            temp[8*9+7:8*9] = block[8*13+7:8*13];
            temp[8*10+7:8*10] = block[8*2+7:8*2];
            temp[8*11+7:8*11] = block[8*7+7:8*7];

            temp[8*12+7:8*12] = block[8*12+7:8*12];
            temp[8*13+7:8*13] = block[8*1+7:8*1];
            temp[8*14+7:8*14] = block[8*6+7:8*6];
            temp[8*15+7:8*15] = block[8*11+7:8*11];

            shiftRow = temp;
        end
    endfunction

    assign new_block = shiftRow(block);

endmodule


