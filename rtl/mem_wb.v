module mem_wb(

    input clk,
    input reset,

    input [31:0] memory_data_in,
    input [31:0] alu_result_in,

    input [4:0] rd_in,

    input RegWrite_in,
    input MemToReg_in,

    output reg [31:0] memory_data_out,
    output reg [31:0] alu_result_out,

    output reg [4:0] rd_out,

    output reg RegWrite_out,
    output reg MemToReg_out

);

always @(posedge clk or posedge reset)
begin

    if(reset)
    begin

        memory_data_out <= 0;
        alu_result_out <= 0;

        rd_out <= 0;

        RegWrite_out <= 0;
        MemToReg_out <= 0;

    end

    else
    begin

        memory_data_out <= memory_data_in;
        alu_result_out <= alu_result_in;

        rd_out <= rd_in;

        RegWrite_out <= RegWrite_in;
        MemToReg_out <= MemToReg_in;

    end

end

endmodule
