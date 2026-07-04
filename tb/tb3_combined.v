// ============================================================
//  TEST BENCH 3 — Combined: Double Forwarding + Store-Load +
//                            Load-Use Hazard
// ============================================================
//
//  This test bench uses the ORIGINAL instruction sequence
//  (SUB x4, x3, x1) which exposed a real CPU bug — the regfile
//  had no WB→ID same-cycle bypass. The fix is in regfile.v,
//  not in the test bench. This TB now passes with the fixed
//  regfile and verifies the complete forwarding + hazard path.
//
//  INSTRUCTION SEQUENCE
//  --------------------
//  [0] ADDI x1, x0,  7   → x1 = 7
//  [1] ADDI x2, x0,  3   → x2 = 3
//  [2] ADD  x3, x1, x2   → x3 = 10   MEM/WB fwd_A=x1, EX/MEM fwd_B=x2 (DOUBLE)
//  [3] SUB  x4, x3, x1   → x4 = 3    EX/MEM fwd_A=x3, WB→ID bypass on x1
//  [4] SW   x4, 4(x0)    → mem[1]=3  EX/MEM fwd_B=x4
//  [5] NOP
//  [6] LW   x5, 4(x0)    → x5 = 3
//  [7] ADD  x6, x5, x4   → LOAD-USE HAZARD on x5 → x6 = 6
//  [8] ADDI x7, x6, 10   → x7 = 16   EX/MEM fwd_A=x6
//
//  WHAT THIS VERIFIES
//  ------------------
//  • EX/MEM forwarding       : instr[3] rs1=x3
//  • WB→ID regfile bypass    : instr[3] rs2=x1 (3 instrs apart — the fixed bug)
//  • Double forwarding       : instr[2] both ports forwarded simultaneously
//  • SW forwarded write_data : instr[4] EX/MEM fwd_B path
//  • Load-use stall (HDU)    : instr[6]→[7] exactly 1 bubble
//  • MEM/WB forward after stall: instr[7] gets x5 from MEM/WB
//  • EX/MEM forward post-stall : instr[8] gets x6 from EX/MEM
//
//  EXPECTED RESULTS
//  ----------------
//  x1=7, x2=3, x3=10, x4=3, x5=3, x6=6, x7=16
//  dmem[1] = 3,  stall_cycles = 1
// ============================================================

`timescale 1ns/1ps

module tb3_combined;

    reg clk, reset;

    pipeline_cpu_top_v5 dut (
        .clk   (clk),
        .reset (reset)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // ── Load instructions ─────────────────────────────────────
    initial begin
        // [0] ADDI x1,x0,7
        dut.imem.memory[0] = 32'h00700093;
        // [1] ADDI x2,x0,3
        dut.imem.memory[1] = 32'h00300113;
        // [2] ADD  x3,x1,x2  ← MEM/WB fwd_A=x1, EX/MEM fwd_B=x2 (DOUBLE)
        dut.imem.memory[2] = 32'h002081B3;
        // [3] SUB  x4,x3,x1  ← EX/MEM fwd_A=x3, WB→ID bypass on x1
        //                       (this was the failing instruction before the fix)
        dut.imem.memory[3] = 32'h40118233;
        // [4] SW   x4,4(x0)  ← EX/MEM fwd_B=x4 via forwarded_B; mem[1]=3
        dut.imem.memory[4] = 32'h00402223;
        // [5] NOP
        dut.imem.memory[5] = 32'h00000013;
        // [6] LW   x5,4(x0)  → x5=3
        dut.imem.memory[6] = 32'h00402283;
        // [7] ADD  x6,x5,x4  ← LOAD-USE HAZARD on x5
        dut.imem.memory[7] = 32'h00428333;
        // [8] ADDI x7,x6,10  ← EX/MEM fwd_A=x6
        dut.imem.memory[8] = 32'h00A30393;
    end

    // ── Stall counter ─────────────────────────────────────────
    integer stall_cycles;
    initial stall_cycles = 0;
    always @(posedge clk) begin
        if (!reset && dut.stall_pc)
            stall_cycles = stall_cycles + 1;
    end

    // ── Forwarding monitor ────────────────────────────────────
    always @(posedge clk) begin
        if (!reset && (dut.forward_A !== 2'b00 || dut.forward_B !== 2'b00))
            $display("  [FWD]  t=%0t  fwd_A=%2b  fwd_B=%2b  PC_fetch=%0d",
                      $time, dut.forward_A, dut.forward_B, dut.pc >> 2);
    end

    // ── Pass/fail tracking ────────────────────────────────────
    integer pass_count, fail_count;

    task check_reg;
        input [4:0]  reg_num;
        input [31:0] actual;
        input [31:0] expected;
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

    task check_mem;
        input [7:0]  word_addr;
        input [31:0] actual;
        input [31:0] expected;
        begin
            if (actual === expected) begin
                $display("  [PASS] dmem[%0d] = %0d  (expected %0d)", word_addr, actual, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] dmem[%0d] = %0d  (expected %0d) *** MISMATCH ***",
                          word_addr, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        reset = 1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0;

        repeat (20) @(posedge clk);
        #1;

        $display("\n========================================");
        $display(" TB3: Combined Forwarding + Hazard Test");
        $display("========================================");

        check_reg(1, dut.rf.registers[1],  32'd7);
        check_reg(2, dut.rf.registers[2],  32'd3);
        check_reg(3, dut.rf.registers[3],  32'd10);
        check_reg(4, dut.rf.registers[4],  32'd3);
        check_reg(5, dut.rf.registers[5],  32'd3);
        check_reg(6, dut.rf.registers[6],  32'd6);
        check_reg(7, dut.rf.registers[7],  32'd16);
        check_mem(1, dut.dmem.memory[1],   32'd3);

        $display("  Stall cycles observed = %0d  (expected 1)", stall_cycles);
        if (stall_cycles === 1) begin
            $display("  [PASS] Stall count is correct");
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Wrong stall count *** MISMATCH ***");
            fail_count = fail_count + 1;
        end

        $display("----------------------------------------");
        if (fail_count == 0)
            $display(" RESULT: ALL %0d CHECKS PASSED", pass_count);
        else
            $display(" RESULT: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("========================================\n");

        $finish;
    end

    initial begin
        $dumpfile("tb3_combined.vcd");
        $dumpvars(0, tb3_combined);
    end

endmodule