// =============================================================================
// NexaCPU — Ambitious Programs Testbench
// Verifies array_sum, multiply, bubble_sort on BOTH single-cycle and pipelined.
//
// HOW TO RUN (from C:\Projects\NexaCPU):
//   iverilog -o hardware/testbenches/programs_tb.vvp \
//            hardware/testbenches/programs_tb.v \
//            hardware/src/alu.v hardware/src/register_file.v \
//            hardware/src/program_counter.v hardware/src/instruction_memory.v \
//            hardware/src/data_memory.v hardware/src/control_unit.v \
//            hardware/src/cpu.v hardware/src/cpu_pipeline.v
//   vvp hardware/testbenches/programs_tb.vvp
// =============================================================================

`timescale 1ns/1ps

module programs_tb;

    reg clk, rst;
    integer pass_count, fail_count, test_num, cycle_count;

    initial clk = 0;
    always #5 clk = ~clk;

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

    // =========================================================================
    // 6 CPU instances — run all in parallel, check after all halt
    // =========================================================================
    wire halt_sc_sum, halt_sc_mul, halt_sc_bsort;
    wire halt_pl_sum, halt_pl_mul, halt_pl_bsort;

    // Single-cycle
    cpu sc_sum (.clk(clk),.rst(rst),.halt(halt_sc_sum),
        .debug_pc(),.debug_instr(),.debug_r1(),.debug_r2(),
        .debug_r3(),.debug_r4(),.debug_alu_result());
    defparam sc_sum.IMEM.MEM_FILE   = "hardware/programs/prog_array_sum.mem";

    cpu sc_mul (.clk(clk),.rst(rst),.halt(halt_sc_mul),
        .debug_pc(),.debug_instr(),.debug_r1(),.debug_r2(),
        .debug_r3(),.debug_r4(),.debug_alu_result());
    defparam sc_mul.IMEM.MEM_FILE   = "hardware/programs/prog_multiply.mem";

    cpu sc_bsort (.clk(clk),.rst(rst),.halt(halt_sc_bsort),
        .debug_pc(),.debug_instr(),.debug_r1(),.debug_r2(),
        .debug_r3(),.debug_r4(),.debug_alu_result());
    defparam sc_bsort.IMEM.MEM_FILE = "hardware/programs/prog_bubble_sort.mem";

    // Pipelined
    cpu_pipeline pl_sum (.clk(clk),.rst(rst),.halt(halt_pl_sum),
        .debug_pc(),.debug_instr(),.debug_if_instr(),.debug_if_pc(),
        .debug_r1(),.debug_r2(),.debug_r3(),.debug_r4(),.debug_alu_result());
    defparam pl_sum.MEM_FILE   = "hardware/programs/prog_array_sum.mem";

    cpu_pipeline pl_mul (.clk(clk),.rst(rst),.halt(halt_pl_mul),
        .debug_pc(),.debug_instr(),.debug_if_instr(),.debug_if_pc(),
        .debug_r1(),.debug_r2(),.debug_r3(),.debug_r4(),.debug_alu_result());
    defparam pl_mul.MEM_FILE   = "hardware/programs/prog_multiply.mem";

    cpu_pipeline pl_bsort (.clk(clk),.rst(rst),.halt(halt_pl_bsort),
        .debug_pc(),.debug_instr(),.debug_if_instr(),.debug_if_pc(),
        .debug_r1(),.debug_r2(),.debug_r3(),.debug_r4(),.debug_alu_result());
    defparam pl_bsort.MEM_FILE = "hardware/programs/prog_bubble_sort.mem";

    // Latch halt signals — prevents combinational glitch issues in multi-CPU sim
    reg latch_sc_sum, latch_sc_mul, latch_sc_bsort;
    reg latch_pl_sum, latch_pl_mul, latch_pl_bsort;

    always @(posedge clk) begin
        if (rst) begin
            latch_sc_sum   <= 0; latch_sc_mul   <= 0; latch_sc_bsort <= 0;
            latch_pl_sum   <= 0; latch_pl_mul   <= 0; latch_pl_bsort <= 0;
        end else begin
            if (halt_sc_sum)   latch_sc_sum   <= 1;
            if (halt_sc_mul)   latch_sc_mul   <= 1;
            if (halt_sc_bsort) latch_sc_bsort <= 1;
            if (halt_pl_sum)   latch_pl_sum   <= 1;
            if (halt_pl_mul)   latch_pl_mul   <= 1;
            if (halt_pl_bsort) latch_pl_bsort <= 1;
        end
    end
    initial begin
        $dumpfile("programs.vcd");
        $dumpvars(0, programs_tb);

        pass_count = 0; fail_count = 0; test_num = 0;

        $display("============================================");
        $display("  NexaCPU — Ambitious Programs Testbench");
        $display("============================================");

        rst = 1; repeat(3) @(posedge clk); rst = 0; #1;

        // Wait for all 6 CPUs to halt (max 3000 cycles total)
        // Use a generous shared window — all CPUs run in parallel on the same clock
        // The slowest program (multiply: ~60 cycles, bubble sort: ~200 cycles) 
        // determines how long we wait.
        cycle_count = 0;
        repeat(2500) begin
            @(posedge clk); #1;
            cycle_count = cycle_count + 1;
        end

        $display("  Ran %0d shared cycles.", cycle_count);

        // =====================================================================
        // Array Sum: 10+20+30+40+50+60 = 210
        // =====================================================================
        $display("\n=== Array Sum (10+20+30+40+50+60 = 210) ===");
        if (latch_sc_sum)
            check16("SC  R3 = 210", sc_sum.REGS.regs[3], 16'd210);
        else begin $display("  FAIL: single-cycle did not halt"); fail_count=fail_count+1; test_num=test_num+1; end
        if (latch_pl_sum)
            check16("PL  R3 = 210", pl_sum.REGS.regs[3], 16'd210);
        else begin $display("  FAIL: pipelined did not halt"); fail_count=fail_count+1; test_num=test_num+1; end

        // =====================================================================
        // Multiply: 7 * 9 = 63
        // =====================================================================
        $display("\n=== Multiply (7 * 9 = 63) ===");
        if (latch_sc_mul)
            check16("SC  R3 = 63",  sc_mul.REGS.regs[3], 16'd63);
        else begin $display("  FAIL: single-cycle did not halt"); fail_count=fail_count+1; test_num=test_num+1; end
        if (latch_pl_mul)
            check16("PL  R3 = 63",  pl_mul.REGS.regs[3], 16'd63);
        else begin $display("  FAIL: pipelined did not halt"); fail_count=fail_count+1; test_num=test_num+1; end

        // =====================================================================
        // Bubble Sort: {5,3,8,1,4} -> {1,3,4,5,8}
        // =====================================================================
        $display("\n=== Bubble Sort ({5,3,8,1,4} -> {1,3,4,5,8}) ===");
        if (latch_sc_bsort) begin
            check16("SC  mem[0]", sc_bsort.DMEM.mem[0], 16'd1);
            check16("SC  mem[1]", sc_bsort.DMEM.mem[1], 16'd3);
            check16("SC  mem[2]", sc_bsort.DMEM.mem[2], 16'd4);
            check16("SC  mem[3]", sc_bsort.DMEM.mem[3], 16'd5);
            check16("SC  mem[4]", sc_bsort.DMEM.mem[4], 16'd8);
        end else begin $display("  FAIL: single-cycle did not halt"); fail_count=fail_count+1; test_num=test_num+1; end
        if (latch_pl_bsort) begin
            check16("PL  mem[0]", pl_bsort.DMEM.mem[0], 16'd1);
            check16("PL  mem[1]", pl_bsort.DMEM.mem[1], 16'd3);
            check16("PL  mem[2]", pl_bsort.DMEM.mem[2], 16'd4);
            check16("PL  mem[3]", pl_bsort.DMEM.mem[3], 16'd5);
            check16("PL  mem[4]", pl_bsort.DMEM.mem[4], 16'd8);
        end else begin $display("  FAIL: pipelined did not halt"); fail_count=fail_count+1; test_num=test_num+1; end

        // ---- Final ----------------------------------------------------------
        $display("\n============================================");
        $display("  Results: %0d passed, %0d failed (of %0d)",
                  pass_count, fail_count, test_num);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED — Ambitious programs verified. ✓");
        else
            $display("  SOME TESTS FAILED.");
        $display("============================================");
        $finish;
    end

endmodule
