module pipeline_cpu_top_v1_tb;

    reg clk;
    reg reset;

    pipeline_cpu_top_v1 dut(
        .clk(clk),
        .reset(reset)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin

        $dumpfile("dump.vcd");
        $dumpvars(0, pipeline_cpu_top_v1_tb);

        reset = 1;
        #10;

        reset = 0;

        #100;

        $finish;

    end

endmodule