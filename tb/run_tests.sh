#!/bin/bash
# ============================================================
#  run_tests.sh  —  Compile & run all 3 pipeline test benches
#  Usage: bash run_tests.sh
#  Requires: iverilog + vvp (Icarus Verilog)
# ============================================================

# Path to your source files — adjust if needed
SRC_DIR="."

# Source files (all modules)
SRCS="$SRC_DIR/pipeline_cpu_top_v5.v \
      $SRC_DIR/pc.v \
      $SRC_DIR/if_id.v \
      $SRC_DIR/id_ex.v \
      $SRC_DIR/ex_mem.v \
      $SRC_DIR/mem_wb.v \
      $SRC_DIR/control_unit.v \
      $SRC_DIR/alu_control.v \
      $SRC_DIR/ALU.v \
      $SRC_DIR/regfile.v \
      $SRC_DIR/imm_gen.v \
      $SRC_DIR/instr_mem.v \
      $SRC_DIR/data_mem.v \
      $SRC_DIR/forwarding_unit.v \
      $SRC_DIR/hazard_detection_unit.v"

echo "======================================================"
echo "  Pipelined CPU Test Suite"
echo "======================================================"

run_tb () {
    local tb_file=$1
    local tb_name=$2
    local out_bin="${tb_name}.out"

    echo ""
    echo ">>> Compiling $tb_name ..."
    iverilog -o "$out_bin" $SRCS "$tb_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "    [COMPILE ERROR] — $tb_name failed to compile"
        return 1
    fi

    echo ">>> Running $tb_name ..."
    vvp "$out_bin"
}

run_tb "tb1_exmem_forwarding.v" "tb1"
run_tb "tb2_load_use_hazard.v"  "tb2"
run_tb "tb3_combined.v"         "tb3"

echo ""
echo "======================================================"
echo "  All test benches complete."
echo "======================================================"
