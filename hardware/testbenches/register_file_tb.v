// =============================================================================
// NexaCPU — Register File Testbench
// Milestone 2
// =============================================================================
//
// HOW TO RUN:
//   cd C:\Projects\NexaCPU
//   $env:PATH += ";C:\iverilog\bin;C:\iverilog\gtkwave\bin"
//   iverilog -o hardware/testbenches/register_file_tb.vvp hardware/testbenches/register_file_tb.v hardware/src/register_file.v
//   vvp hardware/testbenches/register_file_tb.vvp
//
// WHAT THIS TESTS:
//   1. Reset clears all registers to 0
//   2. Write + read-back works for all 7 writable registers (R1–R7)
//   3. R0 is hardwired to 0 — writes to R0 are silently discarded
//   4. Write enable = 0 means no write occurs (register holds previous value)
//   5. Two read ports work independently and simultaneously
//   6. Reading a register immediately after a write returns the NEW value
//      (one cycle later — not the same cycle, because writes are clocked)
//
// READING THE WAVEFORM IN GTKWAVE:
// After running, open waveforms/register_file.vcd in GTKWave.
//   - Drag clk, rst, wr_en, wr_addr, wr_data, rd_addr1, rd_data1 into the
//     signal view.
//   - You'll see clk toggling. Notice that rd_data1 updates ONE CYCLE AFTER
//     the write, not instantly. The write takes effect on the posedge, and
//     the read reflects the new value from that point forward.
//   - This 1-cycle write latency is fundamental to clocked storage.
//
// =============================================================================

`timescale 1ns/1ps

module register_file_tb;

    // ---- Signals ------------------------------------------------------------
    reg        clk;
    reg        rst;
    reg  [2:0] rd_addr1, rd_addr2;
    wire [15:0] rd_data1, rd_data2;
    reg  [2:0] wr_addr;
    reg  [15:0] wr_data;
    reg        wr_en;

    // ---- Instantiate the register file --------------------------------------
    register_file uut (
        .clk(clk),
        .rst(rst),
        .rd_addr1(rd_addr1), .rd_data1(rd_data1),
        .rd_addr2(rd_addr2), .rd_data2(rd_data2),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .wr_en(wr_en)
    );

    // ---- Clock generation ---------------------------------------------------
    // The clock toggles every 5ns → period = 10ns → 100 MHz
    // `initial` runs once. The `forever` loop keeps it running.
    // This is standard testbench clock generation.
    initial clk = 0;
    always #5 clk = ~clk;  // toggle every 5 time units

    // ---- Helper task --------------------------------------------------------
    integer pass_count, fail_count, test_num;

    task check16;
        input [127:0] label;
        input [15:0]  got;
        input [15:0]  expected;
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

    // ---- Convenience: wait for N rising clock edges -------------------------
    task tick;
        input integer n;
        integer j;
        begin
            for (j = 0; j < n; j = j + 1)
                @(posedge clk); #1; // #1 gives combinational outputs time to settle
        end
    endtask

    // ---- Main test ----------------------------------------------------------
    initial begin
        $dumpfile("register_file.vcd");
        $dumpvars(0, register_file_tb);

        pass_count = 0; fail_count = 0; test_num = 0;
        wr_en = 0; wr_addr = 0; wr_data = 0;
        rd_addr1 = 0; rd_addr2 = 0;

        $display("============================================");
        $display("  NexaCPU Register File Testbench — M2");
        $display("============================================");

        // ---- Test 1: Reset --------------------------------------------------
        $display("\n-- Reset --");
        rst = 1;
        tick(2); // hold reset for 2 cycles
        rst = 0;
        // After reset, read all registers — all should be 0
        begin : reset_check
            integer r;
            for (r = 0; r < 8; r = r + 1) begin
                rd_addr1 = r;
                #1; // let combinational read settle
                test_num = test_num + 1;
                if (rd_data1 === 16'd0) begin
                    $display("  PASS [%0d] After reset: R%0d = 0", test_num, r);
                    pass_count = pass_count + 1;
                end else begin
                    $display("  FAIL [%0d] After reset: R%0d = %0d (expected 0)", test_num, r, rd_data1);
                    fail_count = fail_count + 1;
                end
            end
        end

        // ---- Test 2: Write to R1–R7, read back ----------------------------
        $display("\n-- Write and read back (R1-R7) --");
        begin : write_check
            integer r;
            for (r = 1; r < 8; r = r + 1) begin
                // Set up write inputs BEFORE the clock edge
                wr_addr = r;
                wr_data = r * 10;   // R1=10, R2=20, ..., R7=70
                wr_en   = 1;
                tick(1);            // clock edge captures the write
                wr_en   = 0;        // de-assert write enable

                // Now read it back
                rd_addr1 = r;
                #1; // settle
                test_num = test_num + 1;
                if (rd_data1 === r * 10) begin
                    $display("  PASS [%0d] R%0d = %0d", test_num, r, rd_data1);
                    pass_count = pass_count + 1;
                end else begin
                    $display("  FAIL [%0d] R%0d: got %0d, expected %0d",
                              test_num, r, rd_data1, r*10);
                    fail_count = fail_count + 1;
                end
            end
        end

        // ---- Test 3: R0 hardwired to zero -----------------------------------
        $display("\n-- R0 hardwired to zero --");
        wr_addr = 3'd0; wr_data = 16'hABCD; wr_en = 1;
        tick(1);
        wr_en = 0;
        rd_addr1 = 3'd0; #1;
        check16("R0 after write attempt", rd_data1, 16'd0);

        // ---- Test 4: Write enable = 0 means no write ------------------------
        $display("\n-- Write-enable gating --");
        rd_addr1 = 3'd1; #1;
        begin : we_check
            reg [15:0] before;
            before = rd_data1;           // capture current R1 value (should be 10)
            wr_addr = 3'd1; wr_data = 16'hFFFF; wr_en = 0;  // en=0!
            tick(1);
            wr_en = 0;
            rd_addr1 = 3'd1; #1;
            check16("R1 unchanged when wr_en=0", rd_data1, before);
        end

        // ---- Test 5: Two read ports simultaneously --------------------------
        $display("\n-- Dual read ports --");
        // R1=10, R2=20 from earlier writes
        rd_addr1 = 3'd1; rd_addr2 = 3'd2; #1;
        check16("Port1 R1", rd_data1, 16'd10);
        check16("Port2 R2", rd_data2, 16'd20);
        // Both ports at same address return same value
        rd_addr1 = 3'd3; rd_addr2 = 3'd3; #1;
        begin : same_addr
            test_num = test_num + 1;
            if (rd_data1 === rd_data2) begin
                $display("  PASS [%0d] Both ports R3 agree: %0d", test_num, rd_data1);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] Port mismatch: p1=%0d p2=%0d", test_num, rd_data1, rd_data2);
                fail_count = fail_count + 1;
            end
        end

        // ---- Test 6: Overwrite a register -----------------------------------
        $display("\n-- Overwrite R3 --");
        wr_addr = 3'd3; wr_data = 16'd999; wr_en = 1;
        tick(1); wr_en = 0;
        rd_addr1 = 3'd3; #1;
        check16("R3 overwritten to 999", rd_data1, 16'd999);

        // ---- Test 7: Reset clears everything --------------------------------
        $display("\n-- Reset clears all --");
        rst = 1; tick(1); rst = 0;
        begin : reset2
            integer r;
            for (r = 0; r < 8; r = r + 1) begin
                rd_addr1 = r; #1;
                test_num = test_num + 1;
                if (rd_data1 === 16'd0) begin
                    $display("  PASS [%0d] R%0d cleared to 0 after reset", test_num, r);
                    pass_count = pass_count + 1;
                end else begin
                    $display("  FAIL [%0d] R%0d = %0d after reset (expected 0)", test_num, r, rd_data1);
                    fail_count = fail_count + 1;
                end
            end
        end

        // ---- Final report ---------------------------------------------------
        $display("\n============================================");
        $display("  Results: %0d passed, %0d failed (of %0d)",
                  pass_count, fail_count, test_num);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED — Register File verified. ✓");
        else
            $display("  SOME TESTS FAILED — check above.");
        $display("============================================");

        $finish;
    end

endmodule
