module cpu_top(

    input clk,
    input reset

);

    //==================================================
    // Instruction Fetch
    //==================================================

    wire [31:0] pc;
    wire [31:0] instruction;

    //==================================================
    // Decoded Instruction Fields
    //==================================================

    wire [6:0] opcode;
    wire [4:0] rd;
    wire [2:0] funct3;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [6:0] funct7;

    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign funct7 = instruction[31:25];

    //==================================================
    // Control Signals
    //==================================================

    wire RegWrite;
    wire MemRead;
    wire MemWrite;
    wire ALUSrc;
    wire MemToReg;
    wire Branch;
    wire Jump;

    wire [1:0] ALUOp;

    //==================================================
    // Datapath Wires
    //==================================================

    wire [31:0] read_data1;
    wire [31:0] read_data2;

    wire [31:0] imm_out;

    wire [2:0] alu_control;

    wire [31:0] alu_operand_b;
    wire [31:0] alu_result;

    wire [31:0] memory_data;
    wire [31:0] write_back_data;

    wire zero;

    //==================================================
    // PC / Branch / Jump Logic
    //==================================================

    wire [31:0] pc_plus4;
    wire [31:0] branch_target;
    wire [31:0] jal_target;
    wire [31:0] next_pc;

    wire branch_taken;

    assign pc_plus4 = pc + 32'd4;

    assign branch_target = pc + imm_out;

    assign jal_target = pc + imm_out;

    assign branch_taken = Branch & zero;

    assign next_pc =
           (Jump)         ? jal_target :
           (branch_taken) ? branch_target :
                            pc_plus4;

    //==================================================
    // Program Counter
    //==================================================

    pc pc_inst(

        .clk(clk),
        .reset(reset),

        .next_pc(next_pc),

        .pc_out(pc)

    );

    //==================================================
    // Instruction Memory
    //==================================================

    instr_mem imem(

        .address(pc),
        .instruction(instruction)

    );

    //==================================================
    // Main Control Unit
    //==================================================

    control_unit ctrl(

        .opcode(opcode),

        .RegWrite(RegWrite),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .ALUSrc(ALUSrc),
        .MemToReg(MemToReg),
        .Branch(Branch),
        .Jump(Jump),

        .ALUOp(ALUOp)

    );

    //==================================================
    // Register File
    //==================================================

    regfile rf(

        .clk(clk),
        .reg_write(RegWrite),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .write_data(write_back_data),

        .read_data1(read_data1),
        .read_data2(read_data2)

    );

    //==================================================
    // Immediate Generator
    //==================================================

    imm_gen immgen(

        .instruction(instruction),
        .imm_out(imm_out)

    );

    //==================================================
    // ALU Control
    //==================================================

    alu_control alu_ctrl(

        .ALUOp(ALUOp),
        .funct3(funct3),
        .funct7(funct7),

        .alu_control(alu_control)

    );

    //==================================================
    // ALU Input Selection
    //==================================================

    assign alu_operand_b =
           (ALUSrc) ? imm_out : read_data2;

    //==================================================
    // ALU
    //==================================================

    ALU alu_inst(

        .a(read_data1),
        .b(alu_operand_b),

        .alu_control(alu_control),

        .result(alu_result),
        .zero(zero)

    );

    //==================================================
    // Data Memory
    //==================================================

    data_mem dmem(

        .clk(clk),

        .mem_read(MemRead),
        .mem_write(MemWrite),

        .address(alu_result),

        .write_data(read_data2),

        .read_data(memory_data)

    );

    //==================================================
    // Write Back MUX
    //==================================================

    assign write_back_data =
           (Jump)     ? pc_plus4 :
           (MemToReg) ? memory_data :
                        alu_result;

endmodule