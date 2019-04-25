`include "constant.v"

module AES_core (
    input          clk    , // Clock
    input          clk_en , // Clock Enable
    input          rst_n  , // Asynchronous reset active low
    input  [127:0] data   ,
    output [127:0] dataout
);
    wire [127:0] initial1;
    wire [127:0] initial2;
    wire [127:0] mixcolumn;
    function [127:0] subBytes (input [127:0] i);
        reg [127:0] temp;
        begin
            temp[8*0+7:8*0] = constant.s_box[i[8*0+7:8*0]];
            temp[8*1+7:8*1] = constant.s_box[i[8*1+7:8*1]];
            temp[8*2+7:8*2] = constant.s_box[i[8*2+7:8*2]];
            temp[8*3+7:8*3] = constant.s_box[i[8*3+7:8*3]];

            temp[8*4+7:8*4] = constant.s_box[i[8*4+7:8*4]];
            temp[8*5+7:8*5] = constant.s_box[i[8*5+7:8*5]];
            temp[8*6+7:8*6] = constant.s_box[i[8*6+7:8*6]];
            temp[8*7+7:8*7] = constant.s_box[i[8*7+7:8*7]];

            temp[8*8+7:8*8] = constant.s_box[i[8*8+7:8*8]];
            temp[8*9+7:8*9] = constant.s_box[i[8*9+7:8*9]];
            temp[8*10+7:8*10] = constant.s_box[i[8*10+7:8*10]];
            temp[8*11+7:8*11] = constant.s_box[i[8*11+7:8*11]];

            temp[8*12+7:8*12] = constant.s_box[i[8*12+7:8*12]];
            temp[8*13+7:8*13] = constant.s_box[i[8*13+7:8*13]];
            temp[8*14+7:8*14] = constant.s_box[i[8*14+7:8*14]];
            temp[8*15+7:8*15] = constant.s_box[i[8*15+7:8*15]];

            subBytes = temp;
        end
    endfunction

    function [127:0] shiftRow(input [127:0] data);
        reg [127:0] temp;
        begin
            temp[8*0+7:8*0] = constant.s_box[data[8*0+7:8*0]];
            temp[8*1+7:8*1] = constant.s_box[data[8*5+7:8*5]];
            temp[8*2+7:8*2] = constant.s_box[data[8*10+7:8*10]];
            temp[8*3+7:8*3] = constant.s_box[data[8*15+7:8*15]];

            temp[8*4+7:8*4] = constant.s_box[data[8*4+7:8*4]];
            temp[8*5+7:8*5] = constant.s_box[data[8*9+7:8*9]];
            temp[8*6+7:8*6] = constant.s_box[data[8*14+7:8*14]];
            temp[8*7+7:8*7] = constant.s_box[data[8*3+7:8*3]];

            temp[8*8+7:8*8] = constant.s_box[data[8*8+7:8*8]];
            temp[8*9+7:8*9] = constant.s_box[data[8*13+7:8*13]];
            temp[8*10+7:8*10] = constant.s_box[data[8*2+7:8*2]];
            temp[8*11+7:8*11] = constant.s_box[data[8*7+7:8*7]];

            temp[8*12+7:8*12] = constant.s_box[data[8*12+7:8*12]];
            temp[8*13+7:8*13] = constant.s_box[data[8*1+7:8*1]];
            temp[8*14+7:8*14] = constant.s_box[data[8*6+7:8*6]];
            temp[8*15+7:8*15] = constant.s_box[data[8*11+7:8*11]];

            shiftRow = temp;
        end
    endfunction
    function [7:0] mixcolumn32;
        input [7:0] i1,i2,i3,i4;
        begin
            mixcolumn32[7]=i1[6] ^ i2[6] ^ i2[7] ^ i3[7] ^ i4[7];
            mixcolumn32[6]=i1[5] ^ i2[5] ^ i2[6] ^ i3[6] ^ i4[6];
            mixcolumn32[5]=i1[4] ^ i2[4] ^ i2[5] ^ i3[5] ^ i4[5];
            mixcolumn32[4]=i1[3] ^ i1[7] ^ i2[3] ^ i2[4] ^ i2[7] ^ i3[4] ^ i4[4];
            mixcolumn32[3]=i1[2] ^ i1[7] ^ i2[2] ^ i2[3] ^ i2[7] ^ i3[3] ^ i4[3];
            mixcolumn32[2]=i1[1] ^ i2[1] ^ i2[2] ^ i3[2] ^ i4[2];
            mixcolumn32[1]=i1[0] ^ i1[7] ^ i2[0] ^ i2[1] ^ i2[7] ^ i3[1] ^ i4[1];
            mixcolumn32[0]=i1[7] ^ i2[7] ^ i2[0] ^ i3[0] ^ i4[0];
        end
    endfunction
    assign initial1           = subBytes(data[127:0]);
    assign initial2           = shiftRow(initial1[127:0]);
    assign mixcolumn[127:120] = mixcolumn32 (initial2[127:120],initial2[119:112],initial2[111:104],initial2[103:96]);
    assign mixcolumn[119:112] = mixcolumn32 (initial2[119:112],initial2[111:104],initial2[103:96],initial2[127:120]);
    assign mixcolumn[111:104] = mixcolumn32 (initial2[111:104],initial2[103:96],initial2[127:120],initial2[119:112]);
    assign mixcolumn[103:96]  = mixcolumn32 (initial2[103:96],initial2[127:120],initial2[119:112],initial2[111:104]);
    assign mixcolumn[95:88]   = mixcolumn32 (initial2[95:88],initial2[87:80],initial2[79:72],initial2[71:64]);
    assign mixcolumn[87:80]   = mixcolumn32 (initial2[87:80],initial2[79:72],initial2[71:64],initial2[95:88]);
    assign mixcolumn[79:72]   = mixcolumn32 (initial2[79:72],initial2[71:64],initial2[95:88],initial2[87:80]);
    assign mixcolumn[71:64]   = mixcolumn32 (initial2[71:64],initial2[95:88],initial2[87:80],initial2[79:72]);
    assign mixcolumn[63:56]   = mixcolumn32 (initial2[63:56],initial2[55:48],initial2[47:40],initial2[39:32]);
    assign mixcolumn[55:48]   = mixcolumn32 (initial2[55:48],initial2[47:40],initial2[39:32],initial2[63:56]);
    assign mixcolumn[47:40]   = mixcolumn32 (initial2[47:40],initial2[39:32],initial2[63:56],initial2[55:48]);
    assign mixcolumn[39:32]   = mixcolumn32 (initial2[39:32],initial2[63:56],initial2[55:48],initial2[47:40]);
    assign mixcolumn[31:24]   = mixcolumn32 (initial2[31:24],initial2[23:16],initial2[15:8],initial2[7:0]);
    assign mixcolumn[23:16]   = mixcolumn32 (initial2[23:16],initial2[15:8],initial2[7:0],initial2[31:24]);
    assign mixcolumn[15:8]    = mixcolumn32 (initial2[15:8],initial2[7:0],initial2[31:24],initial2[23:16]);
    assign mixcolumn[7:0]     = mixcolumn32 (initial2[7:0],initial2[31:24],initial2[23:16],initial2[15:8]);
    assign dataout            = mixcolumn;
endmodule