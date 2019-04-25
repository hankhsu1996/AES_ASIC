`include "constant.v"

module AES_core (
    input          clk   , // Clock
    input          rst_n , // Asynchronous reset active low
    input  [127:0] block  ,
    output [127:0] new_block
);

    function [127:0] subBytes (input [127:0] block);
        reg [127:0] temp;

        begin
            // find 1st hex
            temp[8*0+7:8*0] = constant.s_box[block[8*0+7:8*0]];
            temp[8*1+7:8*1] = constant.s_box[block[8*1+7:8*1]];
            temp[8*2+7:8*2] = constant.s_box[block[8*2+7:8*2]];
            temp[8*3+7:8*3] = constant.s_box[block[8*3+7:8*3]];

            temp[8*4+7:8*4] = constant.s_box[block[8*4+7:8*4]];
            temp[8*5+7:8*5] = constant.s_box[block[8*5+7:8*5]];
            temp[8*6+7:8*6] = constant.s_box[block[8*6+7:8*6]];
            temp[8*7+7:8*7] = constant.s_box[block[8*7+7:8*7]];

            temp[8*8+7:8*8] = constant.s_box[block[8*8+7:8*8]];
            temp[8*9+7:8*9] = constant.s_box[block[8*9+7:8*9]];
            temp[8*10+7:8*10] = constant.s_box[block[8*10+7:8*10]];
            temp[8*11+7:8*11] = constant.s_box[block[8*11+7:8*11]];

            temp[8*12+7:8*12] = constant.s_box[block[8*12+7:8*12]];
            temp[8*13+7:8*13] = constant.s_box[block[8*13+7:8*13]];
            temp[8*14+7:8*14] = constant.s_box[block[8*14+7:8*14]];
            temp[8*15+7:8*15] = constant.s_box[block[8*15+7:8*15]];
            subBytes = temp;
        end
    endfunction

    // function [127:0] shiftRow(input [127:0] block);
    //     reg [127:0] temp;
    //     begin
    //         temp[8*0+7:8*0] = constant.s_box[block[8*0+7:8*0]];
    //         temp[8*1+7:8*1] = constant.s_box[block[8*5+7:8*5]];
    //         temp[8*2+7:8*2] = constant.s_box[block[8*10+7:8*10]];
    //         temp[8*3+7:8*3] = constant.s_box[block[8*15+7:8*15]];

    //         temp[8*4+7:8*4] = constant.s_box[block[8*4+7:8*4]];
    //         temp[8*5+7:8*5] = constant.s_box[block[8*9+7:8*9]];
    //         temp[8*6+7:8*6] = constant.s_box[block[8*14+7:8*14]];
    //         temp[8*7+7:8*7] = constant.s_box[block[8*3+7:8*3]];

    //         temp[8*8+7:8*8] = constant.s_box[block[8*8+7:8*8]];
    //         temp[8*9+7:8*9] = constant.s_box[block[8*13+7:8*13]];
    //         temp[8*10+7:8*10] = constant.s_box[block[8*2+7:8*2]];
    //         temp[8*11+7:8*11] = constant.s_box[block[8*7+7:8*7]];

    //         temp[8*12+7:8*12] = constant.s_box[block[8*12+7:8*12]];
    //         temp[8*13+7:8*13] = constant.s_box[block[8*1+7:8*1]];
    //         temp[8*14+7:8*14] = constant.s_box[block[8*6+7:8*6]];
    //         temp[8*15+7:8*15] = constant.s_box[block[8*11+7:8*11]];

    //         shiftRow = temp;
    //     end
    // endfunction

    assign new_block = subBytes(block);

endmodule




