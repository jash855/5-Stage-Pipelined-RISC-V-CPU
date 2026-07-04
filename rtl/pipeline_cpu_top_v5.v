// ============================================================
//  RISC-V 5-Stage Pipeline CPU  —  v5
//  Adds: Forwarding Unit + Hazard Detection Unit
//
//  New vs v4:
//   • hazard_detection_unit  → stalls PC + IF/ID, flushes ID/EX
//   • forwarding_unit        → 2-bit muxes on ALU operand A and B
//   • PC, IF/ID, ID/EX updated with stall / flush ports
//   • rs1, rs2 now carried through ID/EX for forwarding checks
// ============================================================

module pipeline_cpu_top_v5 (
    input clk,
    input reset
);

    // ==========================================================
    //  IF STAGE — Instruction Fetch
    // ==========================================================

    wire [31:0] pc;
    wire [31:0] next_pc;
    wire [31:0] instruction;

    wire stall_pc;           // from hazard detection unit

    assign next_pc = pc + 32'd4;   // no branch/jump yet — always +4

    pc pc_inst (
        .clk      (clk),
        .reset    (reset),
        .stall_pc (stall_pc),       // NEW
        .next_pc  (next_pc),
        .pc_out   (pc)
    );

    instr_mem imem (
        .address     (pc),
        .instruction (instruction)
    );

    // ==========================================================
    //  IF/ID PIPELINE REGISTER
    // ==========================================================

    wire [31:0] if_id_pc;
    wire [31:0] if_id_instruction;

    wire stall_if_id;        // from hazard detection unit

    if_id if_id_inst (
        .clk             (clk),
        .reset           (reset),
        .stall_if_id     (stall_if_id),   // NEW
        .flush_if_id     (1'b0),          // branch flush — extend later
        .pc_in           (pc),
        .instruction_in  (instruction),
        .pc_out          (if_id_pc),
        .instruction_out (if_id_instruction)
    );

    // ==========================================================
    //  ID STAGE — Instruction Decode
    // ==========================================================

    wire [6:0] opcode = if_id_instruction[6:0];
    wire [4:0] rd     = if_id_instruction[11:7];
    wire [2:0] funct3 = if_id_instruction[14:12];
    wire [4:0] rs1    = if_id_instruction[19:15];
    wire [4:0] rs2    = if_id_instruction[24:20];
    wire [6:0] funct7 = if_id_instruction[31:25];

    // ── Control Unit ──────────────────────────────────────────

    wire RegWrite, MemRead, MemWrite, ALUSrc, MemToReg, Branch, Jump;
    wire [1:0] ALUOp;

    control_unit ctrl (
        .opcode   (opcode),
        .RegWrite (RegWrite),
        .MemRead  (MemRead),
        .MemWrite (MemWrite),
        .ALUSrc   (ALUSrc),
        .MemToReg (MemToReg),
        .Branch   (Branch),
        .Jump     (Jump),
        .ALUOp    (ALUOp)
    );

    // ── WB-stage wires (declared here because regfile needs them) ──

    wire [31:0] mem_wb_memory_data;
    wire [31:0] mem_wb_alu_result;
    wire [4:0]  mem_wb_rd;
    wire        mem_wb_RegWrite;
    wire        mem_wb_MemToReg;
    wire [31:0] write_back_data;

    assign write_back_data = (mem_wb_MemToReg) ?
                             mem_wb_memory_data :
                             mem_wb_alu_result;

    // ── Register File ─────────────────────────────────────────

    wire [31:0] read_data1;
    wire [31:0] read_data2;

    regfile rf (
        .clk        (clk),
        .reg_write  (mem_wb_RegWrite),
        .rs1        (rs1),
        .rs2        (rs2),
        .rd         (mem_wb_rd),
        .write_data (write_back_data),
        .read_data1 (read_data1),
        .read_data2 (read_data2)
    );

    // ── Immediate Generator ───────────────────────────────────

    wire [31:0] imm_out;

    imm_gen immgen (
        .instruction (if_id_instruction),
        .imm_out     (imm_out)
    );

    // ── ALU Control ───────────────────────────────────────────

    wire [2:0] alu_control;

    alu_control alu_ctrl (
        .ALUOp      (ALUOp),
        .funct3     (funct3),
        .funct7     (funct7),
        .alu_control(alu_control)
    );

    // ==========================================================
    //  HAZARD DETECTION UNIT
    //  Inputs come from: ID stage (rs1, rs2) and ID/EX register
    //  (id_ex_MemRead, id_ex_rd).
    // ==========================================================

    wire flush_id_ex;

    // id_ex outputs needed here — declared early
    wire        id_ex_MemRead;
    wire [4:0]  id_ex_rd;

    hazard_detection_unit hdu (
        .id_ex_MemRead  (id_ex_MemRead),
        .id_ex_rd       (id_ex_rd),
        .if_id_rs1      (rs1),
        .if_id_rs2      (rs2),
        .stall_pc       (stall_pc),
        .stall_if_id    (stall_if_id),
        .flush_id_ex    (flush_id_ex)
    );

    // ==========================================================
    //  ID/EX PIPELINE REGISTER
    // ==========================================================

    wire [31:0] id_ex_pc;
    wire [31:0] id_ex_read_data1;
    wire [31:0] id_ex_read_data2;
    wire [31:0] id_ex_imm;
    wire [4:0]  id_ex_rs1;   // NEW — for forwarding unit
    wire [4:0]  id_ex_rs2;   // NEW — for forwarding unit

    wire        id_ex_RegWrite;
    wire        id_ex_MemWrite;
    wire        id_ex_MemToReg;
    wire        id_ex_ALUSrc;
    wire        id_ex_Branch;
    wire        id_ex_Jump;
    wire [2:0]  id_ex_alu_control;

    id_ex id_ex_inst (
        .clk              (clk),
        .reset            (reset),
        .flush_id_ex      (flush_id_ex),   // NEW

        .pc_in            (if_id_pc),
        .read_data1_in    (read_data1),
        .read_data2_in    (read_data2),
        .imm_in           (imm_out),

        .rs1_in           (rs1),           // NEW
        .rs2_in           (rs2),           // NEW
        .rd_in            (rd),

        .RegWrite_in      (RegWrite),
        .MemRead_in       (MemRead),
        .MemWrite_in      (MemWrite),
        .MemToReg_in      (MemToReg),
        .ALUSrc_in        (ALUSrc),
        .Branch_in        (Branch),
        .Jump_in          (Jump),
        .alu_control_in   (alu_control),

        .pc_out           (id_ex_pc),
        .read_data1_out   (id_ex_read_data1),
        .read_data2_out   (id_ex_read_data2),
        .imm_out          (id_ex_imm),

        .rs1_out          (id_ex_rs1),     // NEW
        .rs2_out          (id_ex_rs2),     // NEW
        .rd_out           (id_ex_rd),

        .RegWrite_out     (id_ex_RegWrite),
        .MemRead_out      (id_ex_MemRead),
        .MemWrite_out     (id_ex_MemWrite),
        .MemToReg_out     (id_ex_MemToReg),
        .ALUSrc_out       (id_ex_ALUSrc),
        .Branch_out       (id_ex_Branch),
        .Jump_out         (id_ex_Jump),
        .alu_control_out  (id_ex_alu_control)
    );

    // ==========================================================
    //  EX/MEM wires (needed by forwarding unit — declared early)
    // ==========================================================

    wire [31:0] ex_mem_alu_result;
    wire [31:0] ex_mem_write_data;
    wire [4:0]  ex_mem_rd;
    wire        ex_mem_RegWrite;
    wire        ex_mem_MemRead;
    wire        ex_mem_MemWrite;
    wire        ex_mem_MemToReg;

    // ==========================================================
    //  FORWARDING UNIT
    //  Compares the source registers of the EX instruction
    //  against the destination registers of MEM and WB stages.
    // ==========================================================

    wire [1:0] forward_A;   // selects ALU operand A
    wire [1:0] forward_B;   // selects ALU operand B

    forwarding_unit fwd (
        .id_ex_rs1      (id_ex_rs1),
        .id_ex_rs2      (id_ex_rs2),

        .ex_mem_rd      (ex_mem_rd),
        .ex_mem_RegWrite(ex_mem_RegWrite),

        .mem_wb_rd      (mem_wb_rd),
        .mem_wb_RegWrite(mem_wb_RegWrite),

        .forward_A      (forward_A),
        .forward_B      (forward_B)
    );

    // ==========================================================
    //  EX STAGE — Execute
    // ==========================================================

    // ── Forwarding muxes for ALU operand A ───────────────────
    //   00 → normal (from ID/EX register)
    //   10 → forward from EX/MEM (one instruction ago)
    //   01 → forward from MEM/WB (two instructions ago)

    reg [31:0] alu_in_A;
    always @(*) begin
        case (forward_A)
            2'b10:   alu_in_A = ex_mem_alu_result;   // EX/MEM forward
            2'b01:   alu_in_A = write_back_data;      // MEM/WB forward
            default: alu_in_A = id_ex_read_data1;     // no forward
        endcase
    end

    // ── Forwarding mux for ALU operand B (before ALUSrc mux) ─

    reg [31:0] forwarded_B;
    always @(*) begin
        case (forward_B)
            2'b10:   forwarded_B = ex_mem_alu_result; // EX/MEM forward
            2'b01:   forwarded_B = write_back_data;   // MEM/WB forward
            default: forwarded_B = id_ex_read_data2;  // no forward
        endcase
    end

    // ── ALUSrc mux (immediate vs register) ───────────────────
    //   Applied AFTER forwarding so forwarded register value is
    //   used when ALUSrc = 0, and immediate when ALUSrc = 1.

    wire [31:0] alu_operand_b = (id_ex_ALUSrc) ? id_ex_imm : forwarded_B;

    // ── ALU ───────────────────────────────────────────────────

    wire [31:0] alu_result;
    wire        zero;

    ALU alu_inst (
        .a           (alu_in_A),
        .b           (alu_operand_b),
        .alu_control (id_ex_alu_control),
        .result      (alu_result),
        .zero        (zero)
    );

    // ==========================================================
    //  EX/MEM PIPELINE REGISTER
    // ==========================================================

    ex_mem ex_mem_inst (
        .clk             (clk),
        .reset           (reset),

        .alu_result_in   (alu_result),
        .write_data_in   (forwarded_B),   // use forwarded rs2 for SW
        .rd_in           (id_ex_rd),

        .RegWrite_in     (id_ex_RegWrite),
        .MemRead_in      (id_ex_MemRead),
        .MemWrite_in     (id_ex_MemWrite),
        .MemToReg_in     (id_ex_MemToReg),

        .alu_result_out  (ex_mem_alu_result),
        .write_data_out  (ex_mem_write_data),
        .rd_out          (ex_mem_rd),

        .RegWrite_out    (ex_mem_RegWrite),
        .MemRead_out     (ex_mem_MemRead),
        .MemWrite_out    (ex_mem_MemWrite),
        .MemToReg_out    (ex_mem_MemToReg)
    );

    // ==========================================================
    //  MEM STAGE — Memory Access
    // ==========================================================

    wire [31:0] memory_data;

    data_mem dmem (
        .clk        (clk),
        .mem_read   (ex_mem_MemRead),
        .mem_write  (ex_mem_MemWrite),
        .address    (ex_mem_alu_result),
        .write_data (ex_mem_write_data),
        .read_data  (memory_data)
    );

    // ==========================================================
    //  MEM/WB PIPELINE REGISTER
    // ==========================================================

    mem_wb mem_wb_inst (
        .clk              (clk),
        .reset            (reset),

        .memory_data_in   (memory_data),
        .alu_result_in    (ex_mem_alu_result),
        .rd_in            (ex_mem_rd),

        .RegWrite_in      (ex_mem_RegWrite),
        .MemToReg_in      (ex_mem_MemToReg),

        .memory_data_out  (mem_wb_memory_data),
        .alu_result_out   (mem_wb_alu_result),
        .rd_out           (mem_wb_rd),

        .RegWrite_out     (mem_wb_RegWrite),
        .MemToReg_out     (mem_wb_MemToReg)
    );

    // ==========================================================
    //  WB STAGE — Write Back
    //  (write_back_data assigned above near the register file)
    // ==========================================================

endmodule


