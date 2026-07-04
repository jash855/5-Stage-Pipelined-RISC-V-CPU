module instr_mem(

    input [31:0] address,
    output [31:0] instruction

);

reg [31:0] memory [0:255];

integer i;

initial begin

    for(i=0;i<256;i=i+1)
        memory[i] = 32'b0;

    memory[0] = 32'h00500113; // ADDI x2,x0,5
    memory[1] = 32'h00002303; // LW   x6,0(x0)
    memory[2] = 32'h00100193; // ADDI x3,x0,1

end

assign instruction = memory[address[31:2]];

endmodule
