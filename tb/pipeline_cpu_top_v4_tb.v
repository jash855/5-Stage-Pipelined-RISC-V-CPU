module pipeline_cpu_top_v4_tb;

    reg clk;
    reg reset;

    pipeline_cpu_top_v4 dut(

        .clk(clk),
        .reset(reset)

    );

    // Clock generation

    initial begin

        clk = 0;

        forever #5 clk = ~clk;

    end

    // Test sequence

    initial begin

        $dumpfile("dump.vcd");
        $dumpvars(0, pipeline_cpu_top_v4_tb);

        reset = 1;

        #20;

        reset = 0;

        #200;

        $finish;

    end

endmodule