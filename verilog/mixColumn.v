`include "constant.v"

module AES_core (
    input          clk      , // Clock
    input          rst_n    , // Asynchronous reset active low
    input  [127:0] block    ,
    output [127:0] new_block
);

    function [7:0] mixColumn32;
        input [7:0] i1,i2,i3,i4;
        begin
            mixColumn32[7]=i1[6]^i2[6]^i2[7]^i3[7]^i4[7];
            mixColumn32[6]=i1[5]^i2[5]^i2[6]^i3[6]^i4[6];
            mixColumn32[5]=i1[4]^i2[4]^i2[5]^i3[5]^i4[5];
            mixColumn32[4]=i1[3]^i1[7]^i2[3]^i2[4]^i2[7]^i3[4]^i4[4];
            mixColumn32[3]=i1[2]^i1[7]^i2[2]^i2[3]^i2[7]^i3[3]^i4[3];
            mixColumn32[2]=i1[1]^i2[1]^i2[2]^i3[2]^i4[2];
            mixColumn32[1]=i1[0]^i1[7]^i2[0]^i2[1]^i2[7]^i3[1]^i4[1];
            mixColumn32[0]=i1[7]^i2[7]^i2[0]^i3[0]^i4[0];
        end
    endfunction

    function [127:0] mixColumn (input [127:0] block);
        begin
            // find 1st hex
            mixColumn[127:120] = mixColumn32 (block[127:120],block[119:112],block[111:104],block[103:96]);
            mixColumn[119:112] = mixColumn32 (block[119:112],block[111:104],block[103:96],block[127:120]);
            mixColumn[111:104] = mixColumn32 (block[111:104],block[103:96],block[127:120],block[119:112]);
            mixColumn[103:96]  = mixColumn32 (block[103:96],block[127:120],block[119:112],block[111:104]);
            mixColumn[95:88]   = mixColumn32 (block[95:88],block[87:80],block[79:72],block[71:64]);
            mixColumn[87:80]   = mixColumn32 (block[87:80],block[79:72],block[71:64],block[95:88]);
            mixColumn[79:72]   = mixColumn32 (block[79:72],block[71:64],block[95:88],block[87:80]);
            mixColumn[71:64]   = mixColumn32 (block[71:64],block[95:88],block[87:80],block[79:72]);
            mixColumn[63:56]   = mixColumn32 (block[63:56],block[55:48],block[47:40],block[39:32]);
            mixColumn[55:48]   = mixColumn32 (block[55:48],block[47:40],block[39:32],block[63:56]);
            mixColumn[47:40]   = mixColumn32 (block[47:40],block[39:32],block[63:56],block[55:48]);
            mixColumn[39:32]   = mixColumn32 (block[39:32],block[63:56],block[55:48],block[47:40]);
            mixColumn[31:24]   = mixColumn32 (block[31:24],block[23:16],block[15:8],block[7:0]);
            mixColumn[23:16]   = mixColumn32 (block[23:16],block[15:8],block[7:0],block[31:24]);
            mixColumn[15:8]    = mixColumn32 (block[15:8],block[7:0],block[31:24],block[23:16]);
            mixColumn[7:0]     = mixColumn32 (block[7:0],block[31:24],block[23:16],block[15:8]);
        end
    endfunction

    assign new_block = mixColumn(block);

endmodule




