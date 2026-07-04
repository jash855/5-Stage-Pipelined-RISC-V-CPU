// ============================================================
//  TEST BENCH 1 — EX/MEM & MEM/WB Forwarding (Pure RAW)
// ============================================================
//
//  WHAT THIS TESTS
//  ---------------
//  Back-to-back RAW (Read After Write) hazards that the
//  FORWARDING UNIT must resolve — no stall should occur.
//
//  INSTRUCTION SEQUENCE
//  --------------------
//  [0] ADDI x1, x0, 10    → x1 = 10
//  [1] ADDI x2, x1,  5    → x2 = 15   EX/MEM fwd: x1 from instr[0]
//  [2] ADD  x3, x1, x2    → x3 = 25   EX/MEM fwd: x2 from instr[1]
//                                      MEM/WB fwd: x1 from instr[0]
//  [3] ADDI x4, x3,  0    → x4 = 25   EX/MEM fwd: x3 from instr[2]
//  [4] ADDI x5, x3,  3    → x5 = 28   MEM/WB fwd: x3 from instr[2]
//
//  FORWARDING EVENTS EXERCISED
//  ----------------------------
//  • EX/MEM → EX  (forward_A/B = 2'b10)  : instr[1] uses x1 from instr[0]
//  • EX/MEM → EX  (forward_B   = 2'b10)  : instr[2] uses x2 from instr[1]
//  • MEM/WB → EX  (forward_A   = 2'b01)  : instr[2] uses x1 from instr[0]
//  • EX/MEM → EX  (forward_A   = 2'b10)  : instr[3] uses x3 from instr[2]
//  • MEM/WB → EX  (forward_A   = 2'b01)  : instr[4] uses x3 from instr[2]
//
//  EXPECTED RESULTS
//  ----------------
//  x1 = 10,  x2 = 15,  x3 = 25,  x4 = 25,  x5 = 28
//
//  PASS CRITERIA
//  -------------
//  All 5 register values match above after the pipeline drains.
//  No unexpected stalls (PC must increment every cycle).
// ============================================================

`timescale 1ns/1ps

module tb1_exmem_forwarding;

    // ── DUT signals ──────────────────────────────────────────
    reg clk, reset;

    pipeline_cpu_top_v5 dut (
        .clk   (clk),
        .reset (reset)
    );

    // ── Clock: 10 ns period ──────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Load instructions into instruction memory ─────────────
    initial begin
        // [0] ADDI x1, x0, 10
        dut.imem.memory[0] = 32'h00A00093;
        // [1] ADDI x2, x1, 5   ← EX/MEM forward on x1
        dut.imem.memory[1] = 32'h00508113;
        // [2] ADD  x3, x1, x2  ← EX/MEM on x2, MEM/WB on x1
        dut.imem.memory[2] = 32'h002081B3;
        // [3] ADDI x4, x3, 0   ← EX/MEM forward on x3
        dut.imem.memory[3] = 32'h00018213;
        // [4] ADDI x5, x3, 3   ← MEM/WB forward on x3
        dut.imem.memory[4] = 32'h00318293;
        // Rest: NOPs (memory already zeroed in instr_mem)
    end

    // ── Simulation ───────────────────────────────────────────
    integer pass_count, fail_count;

    task check;
        input [4:0]  reg_num;
        input [31:0] actual;
        input [31:0] expected;
        input [63:0] label;
        begin
            if (actual === expected) begin
                $display("  [PASS] x%0d = %0d  (expected %0d)", reg_num, actual, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] x%0d = %0d  (expected %0d) *** MISMATCH ***",
                          reg_num, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        // ── Reset ──────────────────────────────────────────────
        reset = 1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0;

        // ── Run enough cycles for 5 instructions + pipeline drain
        //    5 instructions × 1 cycle each + 4 pipeline stages drain = 9+ cycles
        repeat (14) @(posedge clk);
        #1;

        // ── Check results ─────────────────────────────────────
        $display("\n========================================");
        $display(" TB1: EX/MEM & MEM/WB Forwarding Test");
        $display("========================================");
        check(1, dut.rf.registers[1],  32'd10, "x1");
        check(2, dut.rf.registers[2],  32'd15, "x2");
        check(3, dut.rf.registers[3],  32'd25, "x3");
        check(4, dut.rf.registers[4],  32'd25, "x4");
        check(5, dut.rf.registers[5],  32'd28, "x5");

        $display("----------------------------------------");
        if (fail_count == 0)
            $display(" RESULT: ALL %0d CHECKS PASSED", pass_count);
        else
            $display(" RESULT: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("========================================\n");

        $finish;
    end

    // ── Waveform dump (optional, comment out if not needed) ───
    initial begin
        $dumpfile("tb1_exmem_forwarding.vcd");
        $dumpvars(0, tb1_exmem_forwarding);
    end

endmodule
