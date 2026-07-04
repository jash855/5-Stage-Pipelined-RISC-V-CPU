// ============================================================
//  FORWARDING UNIT
// ============================================================
//
//  PURPOSE
//  -------
//  When a later instruction needs a value that an earlier
//  instruction hasn't written to the register file yet, the
//  forwarding unit routes the result directly from wherever
//  it already exists in the pipeline — no stall needed.
//
//  TWO FORWARDING PATHS
//  --------------------
//
//   EX/MEM → EX  (forward_A = 2'b10 or forward_B = 2'b10)
//      The instruction just finished EX and its result is
//      sitting in the EX/MEM register.  Forward that value
//      into the ALU input for the current EX instruction.
//
//   MEM/WB → EX  (forward_A = 2'b01 or forward_B = 2'b01)
//      The instruction finished MEM and its result is in the
//      MEM/WB register (either from memory or the ALU).
//      Forward that into the ALU input.
//
//  NO FORWARDING  (forward_A = 2'b00 or forward_B = 2'b00)
//      No hazard — use the value that came through the
//      ID/EX register normally.
//
//  HOW TO USE THE OUTPUTS IN THE EX STAGE
//  ---------------------------------------
//
//   always @(*) begin
//     case (forward_A)
//       2'b00 : alu_in_A = id_ex_read_data1;       // from reg file
//       2'b10 : alu_in_A = ex_mem_alu_result;       // EX/MEM stage
//       2'b01 : alu_in_A = write_back_data;         // MEM/WB stage
//     endcase
//   end
//
// ============================================================

module forwarding_unit (

    // ── Source registers of the instruction currently in EX ──
    input  [4:0] id_ex_rs1,   // rs1 used by current EX instruction
    input  [4:0] id_ex_rs2,   // rs2 used by current EX instruction

    // ── Destination & write-enable from EX/MEM stage ─────────
    input  [4:0] ex_mem_rd,        // rd of the instruction in MEM
    input        ex_mem_RegWrite,  // does that instruction write a reg?

    // ── Destination & write-enable from MEM/WB stage ─────────
    input  [4:0] mem_wb_rd,        // rd of the instruction in WB
    input        mem_wb_RegWrite,  // does that instruction write a reg?

    // ── Forwarding control outputs ────────────────────────────
    // 2'b00 → no forward  (use ID/EX value)
    // 2'b10 → EX/MEM forward
    // 2'b01 → MEM/WB forward
    output reg [1:0] forward_A,   // controls ALU operand A mux
    output reg [1:0] forward_B    // controls ALU operand B mux

);

always @(*) begin

    // ── Default: no forwarding ────────────────────────────────
    forward_A = 2'b00;
    forward_B = 2'b00;

    // ─────────────────────────────────────────────────────────
    //  EX/MEM FORWARDING  (higher priority — more recent value)
    //  Condition:
    //    • The MEM-stage instruction writes to a register        (ex_mem_RegWrite)
    //    • That destination register is not x0                   (ex_mem_rd != 0)
    //    • It matches the source register of the EX instruction
    // ─────────────────────────────────────────────────────────

    if (ex_mem_RegWrite && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1))
        forward_A = 2'b10;   // forward EX/MEM result into ALU port A

    if (ex_mem_RegWrite && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2))
        forward_B = 2'b10;   // forward EX/MEM result into ALU port B

    // ─────────────────────────────────────────────────────────
    //  MEM/WB FORWARDING  (lower priority — only if EX/MEM
    //  didn't already cover it for the same source register)
    // ─────────────────────────────────────────────────────────

    if (mem_wb_RegWrite && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs1)
        && !(ex_mem_RegWrite && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1)))
        forward_A = 2'b01;   // forward MEM/WB result into ALU port A

    if (mem_wb_RegWrite && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs2)
        && !(ex_mem_RegWrite && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2)))
        forward_B = 2'b01;   // forward MEM/WB result into ALU port B

end

endmodule
