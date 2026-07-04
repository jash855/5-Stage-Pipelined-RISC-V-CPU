// ID/EX pipeline register.
// flush_id_ex = 1 → insert a NOP bubble (clear all control signals).
//   Used by the hazard detection unit on a load-use stall.
// Also needs rs1/rs2 passed through so the hazard unit & forwarding
// unit can inspect the source registers of the instruction in EX.

module id_ex (

    input clk,
    input reset,
    input flush_id_ex,      // NEW: from hazard detection unit

    input [31:0] pc_in,
    input [31:0] read_data1_in,
    input [31:0] read_data2_in,
    input [31:0] imm_in,

    input [4:0]  rs1_in,    // NEW: source reg 1 (needed by forwarding unit)
    input [4:0]  rs2_in,    // NEW: source reg 2 (needed by forwarding unit)
    input [4:0]  rd_in,

    input RegWrite_in,
    input MemRead_in,
    input MemWrite_in,
    input MemToReg_in,
    input ALUSrc_in,
    input Branch_in,
    input Jump_in,

    input [2:0] alu_control_in,

    output reg [31:0] pc_out,
    output reg [31:0] read_data1_out,
    output reg [31:0] read_data2_out,
    output reg [31:0] imm_out,

    output reg [4:0]  rs1_out,  // NEW
    output reg [4:0]  rs2_out,  // NEW
    output reg [4:0]  rd_out,

    output reg RegWrite_out,
    output reg MemRead_out,
    output reg MemWrite_out,
    output reg MemToReg_out,
    output reg ALUSrc_out,
    output reg Branch_out,
    output reg Jump_out,

    output reg [2:0] alu_control_out

);

always @(posedge clk or posedge reset) begin

    if (reset || flush_id_ex) begin

        // Insert NOP: zero out everything, especially all control signals.
        // This means the bubble instruction does nothing —
        // no register write, no memory access.

        pc_out           <= 32'b0;
        read_data1_out   <= 32'b0;
        read_data2_out   <= 32'b0;
        imm_out          <= 32'b0;

        rs1_out          <= 5'b0;
        rs2_out          <= 5'b0;
        rd_out           <= 5'b0;

        RegWrite_out     <= 1'b0;
        MemRead_out      <= 1'b0;
        MemWrite_out     <= 1'b0;
        MemToReg_out     <= 1'b0;
        ALUSrc_out       <= 1'b0;
        Branch_out       <= 1'b0;
        Jump_out         <= 1'b0;

        alu_control_out  <= 3'b000;

    end

    else begin

        pc_out           <= pc_in;
        read_data1_out   <= read_data1_in;
        read_data2_out   <= read_data2_in;
        imm_out          <= imm_in;

        rs1_out          <= rs1_in;
        rs2_out          <= rs2_in;
        rd_out           <= rd_in;

        RegWrite_out     <= RegWrite_in;
        MemRead_out      <= MemRead_in;
        MemWrite_out     <= MemWrite_in;
        MemToReg_out     <= MemToReg_in;
        ALUSrc_out       <= ALUSrc_in;
        Branch_out       <= Branch_in;
        Jump_out         <= Jump_in;

        alu_control_out  <= alu_control_in;

    end

end

endmodule
