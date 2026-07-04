module regfile(

    input clk,
    input reg_write,

    input [4:0] rs1,
    input [4:0] rs2,
    input [4:0] rd,

    input [31:0] write_data,

    output [31:0] read_data1,
    output [31:0] read_data2

);

reg [31:0] registers [31:0];

// WB→ID same-cycle bypass:
// If the register being written in WB is the same as the one
// being read in ID on this posedge, forward write_data directly.
// This handles the 3-instructions-apart case that the forwarding
// unit does not cover (fwd=00 assumes regfile already has the value).
assign read_data1 = (rs1 == 0)                        ? 32'b0     :
                    (reg_write && rd == rs1 && rd != 0) ? write_data :
                    registers[rs1];

assign read_data2 = (rs2 == 0)                        ? 32'b0     :
                    (reg_write && rd == rs2 && rd != 0) ? write_data :
                    registers[rs2];

always @(posedge clk) begin

    if(reg_write && rd != 0)
        registers[rd] <= write_data;

end

endmodule
