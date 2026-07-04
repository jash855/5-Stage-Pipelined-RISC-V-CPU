// IF/ID pipeline register.
// stall_if_id = 1 → freeze (hold current values) for load-use stall.
// flush_if_id = 1 → insert NOP (for branch/jump taken, future use).

module if_id (

    input        clk,
    input        reset,
    input        stall_if_id,   // NEW: hold register (don't update)
    input        flush_if_id,   // NEW: clear register (insert NOP)

    input [31:0] pc_in,
    input [31:0] instruction_in,

    output reg [31:0] pc_out,
    output reg [31:0] instruction_out

);

always @(posedge clk or posedge reset) begin

    if (reset || flush_if_id) begin
        // On reset or flush: load a NOP (x0 = x0 + 0 = addi x0,x0,0)
        pc_out          <= 32'b0;
        instruction_out <= 32'b0;
    end

    else if (!stall_if_id) begin
        // Normal operation
        pc_out          <= pc_in;
        instruction_out <= instruction_in;
    end

    // if stall_if_id == 1 (and no flush): do nothing — hold values

end

endmodule
