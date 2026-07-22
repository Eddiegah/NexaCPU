// =============================================================================
// NexaCPU — Full CPU Testbench
// Milestones 6 & 7
// =============================================================================
//
// HOW TO RUN (from C:\Projects\NexaCPU):
//   iverilog -o hardware/testbenches/cpu_tb.vvp \
//            hardware/testbenches/cpu_tb.v \
//            hardware/src/alu.v hardware/src/register_file.v \
//            hardware/src/program_counter.v hardware/src/instruction_memory.v \
//            hardware/src/data_memory.v hardware/src/control_unit.v \
//            hardware/src/cpu.v
//   vvp hardware/testbenches/cpu_tb.vvp
//
// WHAT THIS TESTS:
//   Three complete programs run on the integrated CPU:
//   1. Arithmetic: verifies ALU operations + register writes
//   2. Countdown loop: verifies CMP, conditional branch (BEQ), JMP
//   3. Fibonacci: verifies loops, STORE, data memory contents
//
// The testbench drives clock and reset, then waits for HALT, then checks
// final register and memory state against known-correct expected values.
//
// =============================================================================

`timescale 1ns/1ps

module cpu_tb;

    reg  clk, rst;
    wire halt;
    wire [5:0]  debug_pc;
    wire [15:0] debug_instr;
    wire [15:0] debug_r1, debug_r2, debug_r3, debug_r4;
    wire [15:0] debug_alu_result;

    // -------------------------------------------------------------------------
    // We instantiate the CPU three times with different MEM_FILE parameters.
    // Each instance runs a different program in parallel during simulation.
    // We clock them all together and wait for each to halt.
    // -------------------------------------------------------------------------

    // --- CPU instance 1: Arithmetic program ----------------------------------
    wire halt1;
    wire [15:0] r1_1, r2_1, r3_1, r4_1, r5_1;

    cpu #() cpu1_wrapper (
        .clk(clk), .rst(rst),
        .halt(halt1),
        .debug_pc(), .debug_instr(),
        .debug_r1(r1_1), .debug_r2(r2_1), .debug_r3(r3_1), .debug_r4(r4_1),
        .debug_alu_result()
    );
    // Note: we override MEM_FILE via defparam below

    defparam cpu1_wrapper.IMEM.MEM_FILE = "hardware/programs/prog_arithmetic.mem";

    // --- CPU instance 2: Countdown program -----------------------------------
    wire halt2;
    wire [15:0] r1_2, r2_2, r3_2, r4_2;

    cpu cpu2_wrapper (
        .clk(clk), .rst(rst),
        .halt(halt2),
        .debug_pc(), .debug_instr(),
        .debug_r1(r1_2), .debug_r2(r2_2), .debug_r3(r3_2), .debug_r4(r4_2),
        .debug_alu_result()
    );

    defparam cpu2_wrapper.IMEM.MEM_FILE = "hardware/programs/prog_countdown.mem";

    // --- CPU instance 3: Fibonacci program -----------------------------------
    wire halt3;
    wire [15:0] r1_3, r2_3, r3_3, r4_3;

    cpu cpu3_wrapper (
        .clk(clk), .rst(rst),
        .halt(halt3),
        .debug_pc(), .debug_instr(),
        .debug_r1(r1_3), .debug_r2(r2_3), .debug_r3(r3_3), .debug_r4(r4_3),
        .debug_alu_result()
    );

    defparam cpu3_wrapper.IMEM.MEM_FILE = "hardware/programs/prog_fibonacci.mem";

    // ---- Clock generation ---------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Counters -----------------------------------------------------------
    integer pass_count, fail_count, test_num;
    integer cycle_count;

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
                $display("  FAIL [%0d] %s: got %0d, expected %0d",
                          test_num, label, got, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ---- Run a CPU until halt, with timeout ---------------------------------
    // We poll `halt_signal` each clock and stop at timeout to prevent hangs
    task run_until_halt;
        input halt_signal;  // Can't pass wire by value cleanly in Verilog-2001
        // So we just run for N cycles and check — see per-test logic below
        begin end
    endtask

    // ---- Main ---------------------------------------------------------------
    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0, cpu_tb);

        pass_count = 0; fail_count = 0; test_num = 0;

        $display("============================================");
        $display("  NexaCPU Full CPU Testbench — M6 & M7");
        $display("============================================");

        // Reset all three CPUs
        rst = 1;
        repeat(3) @(posedge clk);
        rst = 0;
        #1;

        // =====================================================================
        // TEST 1 — Arithmetic Program
        // Expected: R1=5, R2=10, R3=12, R4=24, R5=8, R6=3, R7=15
        // =====================================================================
        $display("\n--- Program 1: Arithmetic ---");
        $display("  Running... (waiting for HALT)");
        cycle_count = 0;
        while (!halt1 && cycle_count < 100) begin
            @(posedge clk); #1;
            cycle_count = cycle_count + 1;
        end
        if (halt1) begin
            $display("  Halted after %0d cycles.", cycle_count);
            check16("Arith R1", r1_1, 16'd5);
            check16("Arith R2", r2_1, 16'd10);
            check16("Arith R3", r3_1, 16'd12);
            check16("Arith R4", r4_1, 16'd24);
            check16("Arith R5", cpu1_wrapper.REGS.regs[5], 16'd8);
            check16("Arith R6", cpu1_wrapper.REGS.regs[6], 16'd3);
            check16("Arith R7", cpu1_wrapper.REGS.regs[7], 16'd15);
        end else begin
            $display("  FAIL: CPU1 did not halt within 100 cycles!");
            fail_count = fail_count + 1; test_num = test_num + 1;
        end

        // =====================================================================
        // TEST 2 — Countdown Loop
        // Expected: R1=0, R2=1, R3=5 (iterations), R4=1
        // =====================================================================
        $display("\n--- Program 2: Countdown Loop ---");
        $display("  Running... (waiting for HALT)");
        cycle_count = 0;
        while (!halt2 && cycle_count < 200) begin
            @(posedge clk); #1;
            cycle_count = cycle_count + 1;
        end
        if (halt2) begin
            $display("  Halted after %0d cycles.", cycle_count);
            check16("Loop R1 (=0)",  r1_2, 16'd0);
            check16("Loop R2 (=1)",  r2_2, 16'd1);
            check16("Loop R3 (=5 iters)", r3_2, 16'd5);
            check16("Loop R4 (=1)",  r4_2, 16'd1);
        end else begin
            $display("  FAIL: CPU2 did not halt within 200 cycles!");
            fail_count = fail_count + 1; test_num = test_num + 1;
        end

        // =====================================================================
        // TEST 3 — Fibonacci
        // Expected data memory: mem[2]=1, mem[3]=2, mem[4]=3,
        //                       mem[5]=5,  mem[6]=8,  mem[7]=13
        // =====================================================================
        $display("\n--- Program 3: Fibonacci ---");
        $display("  Running... (waiting for HALT)");
        cycle_count = 0;
        while (!halt3 && cycle_count < 200) begin
            @(posedge clk); #1;
            cycle_count = cycle_count + 1;
        end
        if (halt3) begin
            $display("  Halted after %0d cycles.", cycle_count);
            check16("Fib mem[2]", cpu3_wrapper.DMEM.mem[2],  16'd1);
            check16("Fib mem[3]", cpu3_wrapper.DMEM.mem[3],  16'd2);
            check16("Fib mem[4]", cpu3_wrapper.DMEM.mem[4],  16'd3);
            check16("Fib mem[5]", cpu3_wrapper.DMEM.mem[5],  16'd5);
            check16("Fib mem[6]", cpu3_wrapper.DMEM.mem[6],  16'd8);
            check16("Fib mem[7]", cpu3_wrapper.DMEM.mem[7],  16'd13);
        end else begin
            $display("  FAIL: CPU3 did not halt within 200 cycles!");
            fail_count = fail_count + 1; test_num = test_num + 1;
        end

        // ---- Final ----------------------------------------------------------
        $display("\n============================================");
        $display("  Results: %0d passed, %0d failed (of %0d)",
                  pass_count, fail_count, test_num);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED — Full CPU verified. ✓");
        else
            $display("  SOME TESTS FAILED — check above.");
        $display("============================================");
        $finish;
    end

endmodule
