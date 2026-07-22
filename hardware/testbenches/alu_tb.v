// =============================================================================
// NexaCPU — ALU Testbench
// Milestone 1
// =============================================================================
//
// HOW TO READ A TESTBENCH:
// A testbench is a simulation harness — it has no ports (it's not a real chip),
// it just drives inputs and observes outputs. The `initial` block runs once at
// simulation time 0 and sequences through test cases using `#N` delays
// (wait N time units).
//
// We use `$display` to print results and `$finish` to end simulation.
// We check results manually (read the output) and also with `$error` assertions
// that will flag failures automatically.
//
// HOW TO RUN:
//   cd hardware
//   iverilog -o testbenches/alu_tb.vvp testbenches/alu_tb.v src/alu.v
//   vvp testbenches/alu_tb.vvp
//
// To generate a VCD waveform file (viewable in GTKWave):
//   The testbench already calls $dumpfile / $dumpvars — the file alu.vcd
//   will appear in the directory you run vvp from.
//
// =============================================================================

`timescale 1ns/1ps  // Time unit = 1 nanosecond, precision = 1 picosecond
                    // This affects how `#10` is interpreted in simulation.
                    // Doesn't matter much for functional tests, but good habit.

module alu_tb;

    // -------------------------------------------------------------------------
    // Declare signals to drive and observe
    //
    // Inputs to the ALU: declared as `reg` so we can assign them in `initial`
    // Outputs from the ALU: declared as `wire` (we observe, we don't drive)
    // -------------------------------------------------------------------------
    reg  [15:0] a;
    reg  [15:0] b;
    reg  [3:0]  op;
    wire [15:0] result;
    wire        zero;
    wire        negative;
    wire        carry;

    // -------------------------------------------------------------------------
    // Instantiate the ALU (the "Unit Under Test")
    //
    // Syntax: module_name instance_name (.port(signal), .port(signal), ...);
    // The .port_name(wire_name) syntax is called "named port connection" —
    // preferred over positional because it's immune to port reordering.
    // -------------------------------------------------------------------------
    alu uut (
        .a(a),
        .b(b),
        .op(op),
        .result(result),
        .zero(zero),
        .negative(negative),
        .carry(carry)
    );

    // -------------------------------------------------------------------------
    // Task: check_result
    //
    // A `task` is like a subroutine in Verilog — reusable code we can call
    // with different arguments. This one checks a result and prints pass/fail.
    // -------------------------------------------------------------------------
    integer test_num;
    integer pass_count;
    integer fail_count;

    task check;
        input [127:0] test_name;  // string label (packed bits used as string)
        input [15:0]  expected_result;
        input         expected_zero;
        input         expected_neg;
        begin
            test_num = test_num + 1;
            if (result === expected_result &&
                zero    === expected_zero   &&
                negative === expected_neg) begin
                $display("  PASS [%0d] %s | result=%0d z=%b n=%b",
                          test_num, test_name, result, zero, negative);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] %s", test_num, test_name);
                $display("       got:      result=%0d z=%b n=%b",
                          result, zero, negative);
                $display("       expected: result=%0d z=%b n=%b",
                          expected_result, expected_zero, expected_neg);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Main test sequence
    // -------------------------------------------------------------------------
    initial begin
        // Set up VCD dump so we can view this in GTKWave
        $dumpfile("alu.vcd");
        $dumpvars(0, alu_tb);   // dump all signals in this module and below

        test_num   = 0;
        pass_count = 0;
        fail_count = 0;

        $display("============================================");
        $display("  NexaCPU ALU Testbench — Milestone 1");
        $display("============================================");

        // ---- LOADI (op=0000) -----------------------------------------------
        $display("\n-- LOADI (pass B through) --");
        op = 4'b0000; a = 16'd0;
        b = 16'd5;    #10; check("LOADI  5", 16'd5,   1'b0, 1'b0);
        b = 16'd0;    #10; check("LOADI  0", 16'd0,   1'b1, 1'b0);
        b = 16'd63;   #10; check("LOADI 63", 16'd63,  1'b0, 1'b0);

        // ---- MOV (op=0011) -------------------------------------------------
        // MOV copies rs1 (operand A) to rd. Set a=42, b is irrelevant.
        $display("\n-- MOV (pass A through) --");
        op = 4'b0011;
        a = 16'd42; b = 16'd0;
        #10; check("MOV 42",   16'd42,  1'b0, 1'b0);

        // ---- ADD (op=0100) -------------------------------------------------
        $display("\n-- ADD --");
        op = 4'b0100;
        a = 16'd10;  b = 16'd20; #10; check("10+20",    16'd30,    1'b0, 1'b0);
        a = 16'd0;   b = 16'd0;  #10; check("0+0",      16'd0,     1'b1, 1'b0);
        a = 16'd255; b = 16'd1;  #10; check("255+1",    16'd256,   1'b0, 1'b0);
        // Overflow: 65535 + 1 should set carry and result = 0
        a = 16'hFFFF; b = 16'd1; #10;
        if (result === 16'd0 && carry === 1'b1) begin
            $display("  PASS [%0d] ADD overflow: result=0, carry=1", test_num+1);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [%0d] ADD overflow: got result=%0d carry=%b", test_num+1, result, carry);
            fail_count = fail_count + 1;
        end
        test_num = test_num + 1;

        // ---- SUB (op=0101) -------------------------------------------------
        $display("\n-- SUB --");
        op = 4'b0101;
        a = 16'd20;  b = 16'd10; #10; check("20-10",   16'd10,  1'b0, 1'b0);
        a = 16'd5;   b = 16'd5;  #10; check("5-5=0",   16'd0,   1'b1, 1'b0);
        // Negative result: 3-10 = -7, which in 16-bit two's complement is 0xFFF9
        // MSB will be 1, so negative flag should be set
        a = 16'd3;   b = 16'd10; #10;
        if (result[15] === 1'b1 && zero === 1'b0) begin
            $display("  PASS [%0d] SUB negative: result=%0d (0x%h), neg=1", test_num+1, $signed(result), result);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [%0d] SUB negative: got result=%0d neg=%b", test_num+1, result, negative);
            fail_count = fail_count + 1;
        end
        test_num = test_num + 1;

        // ---- AND (op=0110) -------------------------------------------------
        $display("\n-- AND --");
        op = 4'b0110;
        a = 16'b1111_0000_1111_0000;
        b = 16'b1010_1010_1010_1010;
        #10; check("AND pattern", 16'b1010_0000_1010_0000, 1'b0, 1'b1);
        a = 16'hFFFF; b = 16'h0000; #10; check("AND x&0=0", 16'h0000, 1'b1, 1'b0);
        a = 16'hFFFF; b = 16'hFFFF; #10; check("AND x&x=x", 16'hFFFF, 1'b0, 1'b1);

        // ---- OR (op=0111) --------------------------------------------------
        $display("\n-- OR --");
        op = 4'b0111;
        a = 16'b1010_0000_0000_0000;
        b = 16'b0000_0000_0000_0101;
        #10; check("OR pattern", 16'b1010_0000_0000_0101, 1'b0, 1'b1);
        a = 16'h0000; b = 16'h0000; #10; check("OR 0|0=0", 16'h0000, 1'b1, 1'b0);

        // ---- NOT (op=1000) -------------------------------------------------
        $display("\n-- NOT --");
        op = 4'b1000;
        a = 16'h0000; b = 16'hXXXX; // B is irrelevant for NOT
        #10; check("NOT 0=FFFF", 16'hFFFF, 1'b0, 1'b1);
        a = 16'hFFFF;
        #10; check("NOT FFFF=0", 16'h0000, 1'b1, 1'b0);
        a = 16'h00FF;
        #10; check("NOT 00FF=FF00", 16'hFF00, 1'b0, 1'b1);

        // ---- CMP (op=1001) — only flags matter, result not used -----------
        $display("\n-- CMP (flags only) --");
        op = 4'b1001;
        // Equal values: result = 0, zero should be set
        a = 16'd42; b = 16'd42; #10;
        if (zero === 1'b1 && negative === 1'b0) begin
            $display("  PASS [%0d] CMP equal: z=1, n=0", test_num+1);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [%0d] CMP equal: got z=%b n=%b", test_num+1, zero, negative);
            fail_count = fail_count + 1;
        end
        test_num = test_num + 1;
        // a < b: result negative
        a = 16'd3; b = 16'd10; #10;
        if (zero === 1'b0 && negative === 1'b1) begin
            $display("  PASS [%0d] CMP less: z=0, n=1", test_num+1);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [%0d] CMP less: got z=%b n=%b", test_num+1, zero, negative);
            fail_count = fail_count + 1;
        end
        test_num = test_num + 1;
        // a > b: result positive
        a = 16'd10; b = 16'd3; #10;
        if (zero === 1'b0 && negative === 1'b0) begin
            $display("  PASS [%0d] CMP greater: z=0, n=0", test_num+1);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [%0d] CMP greater: got z=%b n=%b", test_num+1, zero, negative);
            fail_count = fail_count + 1;
        end
        test_num = test_num + 1;

        // ---- Final report --------------------------------------------------
        $display("\n============================================");
        $display("  Results: %0d passed, %0d failed (of %0d)",
                  pass_count, fail_count, test_num);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED — ALU verified. ✓");
        else
            $display("  SOME TESTS FAILED — check output above.");
        $display("============================================");

        $finish;
    end

    // -------------------------------------------------------------------------
    // Optional: monitor — prints a line every time any signal changes.
    // Useful for debugging, can be noisy. Comment out when not needed.
    // -------------------------------------------------------------------------
    // initial begin
    //     $monitor("t=%0t op=%b a=%0d b=%0d | result=%0d z=%b n=%b c=%b",
    //               $time, op, a, b, result, zero, negative, carry);
    // end

endmodule
