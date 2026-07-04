module alu_control(             //this one helps to increase the R format instructions

    input  [1:0] ALUOp,
    input  [2:0] funct3,
    input  [6:0] funct7,

    output reg [2:0] alu_control

);

always @(*) begin

    case(ALUOp)

        // LW, SW, ADDI
        2'b00:
            alu_control = 3'b000; // ADD

        // BEQ
        2'b01:
            alu_control = 3'b001; // SUB

        // R-Type
        2'b10: begin

            case({funct7, funct3})

                10'b0000000_000:
                    alu_control = 3'b000; // ADD

                10'b0100000_000:
                    alu_control = 3'b001; // SUB

                10'b0000000_111:
                    alu_control = 3'b010; // AND

                10'b0000000_110:
                    alu_control = 3'b011; // OR

                10'b0000000_100:
                    alu_control = 3'b100; // XOR

                default:
                    alu_control = 3'b000;

            endcase

        end

        default:
            alu_control = 3'b000;

    endcase

end

endmodule
