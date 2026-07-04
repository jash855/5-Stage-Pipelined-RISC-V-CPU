// ============================================================
//  HAZARD DETECTION UNIT
// ============================================================
//
//  PURPOSE
//  -------
//  Detects load-use hazards — the ONE case forwarding alone
//  cannot fix.
//
//  WHAT IS A LOAD-USE HAZARD?
//  --------------------------
//  When a LOAD instruction (lw) is immediately followed by an
//  instruction that USES the loaded register, the data is not
//  available in time even with forwarding.
//
//  Timeline without a stall:
//
//   Cycle:    1    2    3    4    5
//   lw  x1   IF   ID   EX  MEM   WB   ← result ready after MEM (cycle 4)
//   add x2,x1,x3  IF   ID   EX  ...   ← needs x1 at START of EX (cycle 3)
//                                         TOO EARLY — need a stall!
//
//  After inserting ONE bubble (stall):
//
//   Cycle:    1    2    3    4    5    6
//   lw  x1   IF   ID   EX  MEM   WB
//   (bubble)       IF   ID  ---  ---
//   add x2         IF   ID   EX  MEM   WB
//                                       Now MEM/WB forwarding works!
//
//  WHAT THIS UNIT DOES ON A STALL
//  --------------------------------
//  It asserts three control signals:
//
//   stall_pc   = 1  → freeze the PC (don't advance to next instruction)
//   stall_if_id = 1 → freeze the IF/ID register (hold current instruction)
//   flush_id_ex = 1 → insert a NOP bubble into the ID/EX register
//                      (clears all control signals so nothing happens)
//
// ============================================================

module hazard_detection_unit (

    // ── Is the instruction in EX a load? ─────────────────────
    input        id_ex_MemRead,   // 1 if the EX-stage instruction is lw

    // ── Which register does the lw write to? ─────────────────
    input  [4:0] id_ex_rd,        // destination register of the lw

    // ── Which registers does the NEXT instruction (in ID) read?
    input  [4:0] if_id_rs1,       // source register 1 of the ID instruction
    input  [4:0] if_id_rs2,       // source register 2 of the ID instruction

    // ── Outputs: what to do when a hazard is detected ─────────
    output reg   stall_pc,        // 1 → hold PC (do not increment)
    output reg   stall_if_id,     // 1 → hold IF/ID register
    output reg   flush_id_ex      // 1 → clear ID/EX register (insert NOP)

);

always @(*) begin

    // Default: no hazard, everything runs normally
    stall_pc    = 1'b0;
    stall_if_id = 1'b0;
    flush_id_ex = 1'b0;

    // ─────────────────────────────────────────────────────────
    //  LOAD-USE HAZARD CHECK
    //  Trigger when ALL of the following are true:
    //   1. The instruction in EX is a load (id_ex_MemRead == 1)
    //   2. The load's destination register is not x0
    //   3. The load's destination matches rs1 OR rs2 of the
    //      instruction currently being decoded (in ID)
    // ─────────────────────────────────────────────────────────

    if (id_ex_MemRead &&
        (id_ex_rd != 5'b0) &&
        ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2)))
    begin

        stall_pc    = 1'b1;  // freeze PC — re-fetch same instruction
        stall_if_id = 1'b1;  // freeze IF/ID — keep the hazard instruction
        flush_id_ex = 1'b1;  // flush ID/EX — insert a NOP bubble

    end

end

endmodule
