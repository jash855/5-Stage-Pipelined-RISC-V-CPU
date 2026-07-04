`timescale 1ns/1ps

module cpu_top_tb;

    reg clk;
    reg reset;

    cpu_top dut(

        .clk(clk),
        .reset(reset)

    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin

        $dumpfile("waveforms/cpu.vcd");
        $dumpvars(0, cpu_top_tb);

        clk = 0;
        reset = 1;

        #10;
        reset = 0;

        // Let CPU run
        #200;

        $finish;

    end

endmodule