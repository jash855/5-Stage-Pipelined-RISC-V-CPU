module imm_gen(

    input [31:0] instruction,
    output reg [31:0] imm_out

);

always @(*) begin

    case(instruction[6:0])

        // I-Type (ADDI, LW)

        7'b0010011,
        7'b0000011:

            imm_out = {{20{instruction[31]}},
                       instruction[31:20]};

        // S-Type (SW)

        7'b0100011:

            imm_out = {{20{instruction[31]}},
                       instruction[31:25],
                       instruction[11:7]};

        // B-Type (BEQ)

        7'b1100011:

            imm_out = {{19{instruction[31]}},
                       instruction[31],
                       instruction[7],
                       instruction[30:25],
                       instruction[11:8],
                       1'b0};

        // J-Type (JAL)

        7'b1101111:

            imm_out = {{11{instruction[31]}},
                       instruction[31],
                       instruction[19:12],
                       instruction[20],
                       instruction[30:21],
                       1'b0};

        default:

            imm_out = 32'b0;

    endcase

end

endmodule
