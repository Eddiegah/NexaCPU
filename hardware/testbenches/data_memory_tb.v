// =============================================================================
// NexaCPU — Data Memory Testbench
// Milestone 5
// =============================================================================
`timescale 1ns/1ps

module data_memory_tb;

    reg        clk, wr_en, rd_en;
    reg  [5:0] addr;
    reg  [15:0] wr_data;
    wire [15:0] rd_data;

    data_memory uut (.clk(clk), .addr(addr), .wr_data(wr_data),
                     .wr_en(wr_en), .rd_en(rd_en), .rd_data(rd_data));

    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_count, fail_count, test_num;

    task check16;
        input [127:0] label;
        input [15:0] got;
        input [15:0] expected;
        begin
            test_num = test_num + 1;
            if (got === expected) begin
                $display("  PASS [%0d] %s = %0d", test_num, label, got);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] %s: got %0d, expected %0d", test_num, label, got, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task tick;
        begin
            @(posedge clk); #1;
        end
    endtask

    initial begin
        $dumpfile("data_memory.vcd");
        $dumpvars(0, data_memory_tb);
        pass_count = 0; fail_count = 0; test_num = 0;
        wr_en = 0; rd_en = 0; addr = 0; wr_data = 0;

        $display("============================================");
        $display("  NexaCPU Data Memory Testbench — M5");
        $display("============================================");

        // Initial state: all zeros
        $display("\n-- Initial state (all zero) --");
        rd_en = 1; addr = 0; #1; check16("mem[0] initially", rd_data, 16'd0);
        addr = 63; #1;          check16("mem[63] initially", rd_data, 16'd0);

        // Write and read back
        $display("\n-- Write and read back --");
        addr = 5; wr_data = 16'd42; wr_en = 1; tick; wr_en = 0;
        addr = 5; rd_en = 1; #1;   check16("mem[5]=42", rd_data, 16'd42);

        addr = 63; wr_data = 16'd1234; wr_en = 1; tick; wr_en = 0;
        addr = 63; #1;               check16("mem[63]=1234", rd_data, 16'd1234);

        // rd_en=0 returns 0
        $display("\n-- rd_en gating --");
        rd_en = 0; addr = 5; #1;
        check16("rd_en=0 gives 0", rd_data, 16'd0);

        // Write without read enable doesn't disturb other locations
        $display("\n-- Write isolation --");
        rd_en = 1; addr = 6; wr_data = 16'd99; wr_en = 1; tick; wr_en = 0;
        addr = 5; #1; check16("mem[5] unchanged after write to [6]", rd_data, 16'd42);
        addr = 6; #1; check16("mem[6]=99", rd_data, 16'd99);

        // Overwrite
        $display("\n-- Overwrite --");
        addr = 5; wr_data = 16'd777; wr_en = 1; tick; wr_en = 0;
        addr = 5; #1; check16("mem[5] overwritten to 777", rd_data, 16'd777);

        $display("\n============================================");
        $display("  Results: %0d passed, %0d failed (of %0d)",
                  pass_count, fail_count, test_num);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED — Data Memory verified. ✓");
        else
            $display("  SOME TESTS FAILED.");
        $display("============================================");
        $finish;
    end
endmodule
