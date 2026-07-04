// ============================================================
//  TEST BENCH 2 — Load-Use Hazard (HDU Stall + MEM/WB Forward)
// ============================================================
//
//  WHAT THIS TESTS
//  ---------------
//  A load instruction (LW) immediately followed by an instruction
//  that uses the loaded register. Forwarding alone cannot fix this
//  (the value isn't ready until after MEM stage), so the HAZARD
//  DETECTION UNIT must insert exactly ONE stall cycle.
//
//  INSTRUCTION SEQUENCE
//  --------------------
//  [0] ADDI x1, x0, 42   → x1 = 42
//  [1] SW   x1, 0(x0)    → mem[0] = 42  (no hazard — gap after ADDI)
//  [2] NOP  (ADDI x0,x0,0)               (pipeline gap for SW to complete)
//  [3] LW   x2, 0(x0)    → x2 = 42      (load from mem[0])
//  [4] ADD  x3, x2, x2   → x3 = 84      *** LOAD-USE HAZARD on x2 ***
//                                         HDU: stall_pc=1, stall_if_id=1,
//                                              flush_id_ex=1 (1 bubble)
//                                         After stall: MEM/WB fwd x2 → ALU
//  [5] ADDI x4, x3, 1    → x4 = 85      EX/MEM forward on x3
//
//  HAZARD / FORWARDING EVENTS EXERCISED
//  --------------------------------------
//  • HDU detects: id_ex_MemRead=1, id_ex_rd==if_id_rs1 (x2==x2)
//  • HDU asserts: stall_pc=1, stall_if_id=1, flush_id_ex=1
//  • One NOP bubble inserted; ADD re-enters EX the next cycle
//  • MEM/WB forwarding resolves x2 for the ADD in the re-issued cycle
//  • EX/MEM forwarding resolves x3 for ADDI x4
//
//  EXPECTED RESULTS
//  ----------------
//  x1 = 42, x2 = 42, x3 = 84, x4 = 85
//  mem[0] = 42
//
//  PASS CRITERIA
//  -------------
//  All register and memory values match. The stall must add exactly
//  one extra cycle (observable via $monitor if needed).
// ============================================================

`timescale 1ns/1ps

module tb2_load_use_hazard;

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
        // [0] ADDI x1, x0, 42
        dut.imem.memory[0] = 32'h02A00093;
        // [1] SW x1, 0(x0)   → mem[0] = 42
        dut.imem.memory[1] = 32'h00102023;
        // [2] NOP (ADDI x0, x0, 0)
        dut.imem.memory[2] = 32'h00000013;
        // [3] LW x2, 0(x0)   → x2 = 42
        dut.imem.memory[3] = 32'h00002103;
        // [4] ADD x3, x2, x2  ← LOAD-USE HAZARD on x2 (HDU fires)
        dut.imem.memory[4] = 32'h002101B3;
        // [5] ADDI x4, x3, 1  ← EX/MEM forward on x3
        dut.imem.memory[5] = 32'h00118213;
    end

    // ── Stall monitor: counts stall cycles ───────────────────
    integer stall_cycles;
    initial stall_cycles = 0;
    always @(posedge clk) begin
        if (!reset && dut.stall_pc)
            stall_cycles = stall_cycles + 1;
    end

    // ── Simulation ───────────────────────────────────────────
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
        input [7:0]  addr_word;  // word index
        input [31:0] actual;
        input [31:0] expected;
        begin
            if (actual === expected) begin
                $display("  [PASS] dmem[%0d] = %0d  (expected %0d)", addr_word, actual, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] dmem[%0d] = %0d  (expected %0d) *** MISMATCH ***",
                          addr_word, actual, expected);
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

        // ── Run: 6 instructions + 1 stall bubble + 4 drain cycles
        repeat (16) @(posedge clk);
        #1;

        // ── Results ───────────────────────────────────────────
        $display("\n========================================");
        $display(" TB2: Load-Use Hazard Detection Test");
        $display("========================================");

        check_reg(1, dut.rf.registers[1],  32'd42);
        check_reg(2, dut.rf.registers[2],  32'd42);
        check_reg(3, dut.rf.registers[3],  32'd84);
        check_reg(4, dut.rf.registers[4],  32'd85);
        check_mem(0, dut.dmem.memory[0],   32'd42);

        // ── Verify exactly 1 stall was inserted ───────────────
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

    // ── Waveform dump ─────────────────────────────────────────
    initial begin
        $dumpfile("tb2_load_use_hazard.vcd");
        $dumpvars(0, tb2_load_use_hazard);
    end

endmodule
