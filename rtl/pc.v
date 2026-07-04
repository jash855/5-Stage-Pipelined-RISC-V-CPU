// PC register — holds the current program counter.
// stall_pc = 1 → do NOT update PC (freeze it in place for load-use stall).

module pc (

    input        clk,
    input        reset,
    input        stall_pc,      // NEW: from hazard detection unit
    input [31:0] next_pc,

    output reg [31:0] pc_out

);

always @(posedge clk or posedge reset) begin

    if (reset)
        pc_out <= 32'b0;

    else if (!stall_pc)         // only advance when not stalled
        pc_out <= next_pc;

    // if stall_pc == 1: do nothing — pc_out keeps its value

end

endmodule

