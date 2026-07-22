// =============================================================================
// NexaCPU — Program Counter + Instruction Memory Testbench
// Milestone 3
// =============================================================================
//
// HOW TO RUN (from C:\Projects\NexaCPU):
//   iverilog -o hardware/testbenches/program_counter_tb.vvp \
//            hardware/testbenches/program_counter_tb.v \
//            hardware/src/program_counter.v \
//            hardware/src/instruction_memory.v
//   vvp hardware/testbenches/program_counter_tb.vvp
//
// WHAT THIS TESTS:
//   1. PC starts at 0 after reset
//   2. PC increments by 1 each clock cycle
//   3. PC can be loaded with an arbitrary value (jump)
//   4. Instruction memory returns the correct 16-bit instruction for each PC
//   5. Sequence: reset → fetch 4 instructions in order, checking each value
//
// =============================================================================

`timescale 1ns/1ps

module program_counter_tb;

    reg        clk, rst, load;
    reg  [5:0] next_pc;
    wire [5:0] pc;
    wire [15:0] instr;

    // Instantiate PC
    program_counter pc_inst (
        .clk(clk), .rst(rst),
        .load(load), .next_pc(next_pc),
        .pc(pc)
    );

    // Instantiate instruction memory — point at our test program
    instruction_memory #(.MEM_FILE("hardware/programs/test_imem.mem")) imem (
        .pc(pc),
        .instr(instr)
    );

    // Clock: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_count, fail_count, test_num;

    task check_pc_instr;
        input [5:0]  exp_pc;
        input [15:0] exp_instr;
        input [63:0] label;
        begin
            test_num = test_num + 1;
            if (pc === exp_pc && instr === exp_instr) begin
                $display("  PASS [%0d] %s: PC=%0d instr=0x%04X",
                          test_num, label, pc, instr);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] %s: got PC=%0d instr=0x%04X, expected PC=%0d instr=0x%04X",
                          test_num, label, pc, instr, exp_pc, exp_instr);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("program_counter.vcd");
        $dumpvars(0, program_counter_tb);

        pass_count = 0; fail_count = 0; test_num = 0;
        load = 0; next_pc = 0;

        $display("============================================");
        $display("  NexaCPU PC + IMEM Testbench — M3");
        $display("============================================");

        // ---- Reset ----------------------------------------------------------
        $display("\n-- Reset --");
        rst = 1; @(posedge clk); #1;
        rst = 0;
        // PC should be 0, instruction should be test_imem.mem[0] = 0x0205 (LOADI R1,5)
        check_pc_instr(6'd0, 16'h0205, "After reset");

        // ---- Sequential fetch: PC increments each cycle --------------------
        $display("\n-- Sequential fetch --");
        @(posedge clk); #1;
        check_pc_instr(6'd1, 16'h040A, "Cycle 1 (LOADI R2,10)");

        @(posedge clk); #1;
        check_pc_instr(6'd2, 16'h4642, "Cycle 2 (ADD R3,R1,R2)");

        @(posedge clk); #1;
        check_pc_instr(6'd3, 16'hF000, "Cycle 3 (HALT)");

        // ---- Jump (load) ---------------------------------------------------
        $display("\n-- Jump to address 1 --");
        load = 1; next_pc = 6'd1;
        @(posedge clk); #1;
        load = 0;
        check_pc_instr(6'd1, 16'h040A, "After jump to 1");

        // ---- Jump to 0 (restart) -------------------------------------------
        load = 1; next_pc = 6'd0;
        @(posedge clk); #1;
        load = 0;
        check_pc_instr(6'd0, 16'h0205, "After jump to 0 (restart)");

        // ---- Resume incrementing after jump --------------------------------
        @(posedge clk); #1;
        check_pc_instr(6'd1, 16'h040A, "Resume increment after jump");

        // ---- Final ----------------------------------------------------------
        $display("\n============================================");
        $display("  Results: %0d passed, %0d failed (of %0d)",
                  pass_count, fail_count, test_num);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED — PC + IMEM verified. ✓");
        else
            $display("  SOME TESTS FAILED.");
        $display("============================================");
        $finish;
    end

endmodule
