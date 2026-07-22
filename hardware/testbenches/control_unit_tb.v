// =============================================================================
// NexaCPU — Control Unit Testbench
// Milestone 4
// =============================================================================
//
// HOW TO RUN (from C:\Projects\NexaCPU):
//   iverilog -o hardware/testbenches/control_unit_tb.vvp \
//            hardware/testbenches/control_unit_tb.v \
//            hardware/src/control_unit.v
//   vvp hardware/testbenches/control_unit_tb.vvp
//
// WHAT THIS TESTS:
//   For every opcode in the ISA, verify that the control unit generates the
//   correct set of control signals. This is the most important test in Phase 1
//   because an incorrect control signal silently misbehaves at runtime —
//   e.g. reg_write=1 on a STORE instruction would corrupt a register.
//
// =============================================================================

`timescale 1ns/1ps

module control_unit_tb;

    // Inputs
    reg  [15:0] instr;
    reg         zero, negative;

    // Outputs
    wire [2:0]  rd, rs1, rs2;
    wire [5:0]  imm6;
    wire [3:0]  alu_op;
    wire        alu_src, reg_write, mem_to_reg, mem_read, mem_write;
    wire        pc_src;
    wire [5:0]  pc_next;
    wire        halt;

    // Instantiate
    control_unit uut (
        .instr(instr), .zero(zero), .negative(negative),
        .rd(rd), .rs1(rs1), .rs2(rs2), .imm6(imm6),
        .alu_op(alu_op), .alu_src(alu_src),
        .reg_write(reg_write), .mem_to_reg(mem_to_reg),
        .mem_read(mem_read), .mem_write(mem_write),
        .pc_src(pc_src), .pc_next(pc_next),
        .halt(halt)
    );

    integer pass_count, fail_count, test_num;

    // Helper task: check a single 1-bit control signal
    task check1;
        input [127:0] name;
        input         got, expected;
        begin
            test_num = test_num + 1;
            if (got === expected) begin
                $display("    PASS [%0d] %s = %b", test_num, name, got);
                pass_count = pass_count + 1;
            end else begin
                $display("    FAIL [%0d] %s: got %b, expected %b", test_num, name, got, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Build a full instruction word from fields
    function [15:0] make_instr;
        input [3:0] op;
        input [2:0] rd_f, rs1_f;
        input [5:0] imm_rs2;
        begin
            make_instr = {op, rd_f, rs1_f, imm_rs2};
        end
    endfunction

    initial begin
        $dumpfile("control_unit.vcd");
        $dumpvars(0, control_unit_tb);

        pass_count = 0; fail_count = 0; test_num = 0;
        zero = 0; negative = 0;

        $display("============================================");
        $display("  NexaCPU Control Unit Testbench — M4");
        $display("============================================");

        // ---- LOADI R1, 5 ---------------------------------------------------
        $display("\n-- LOADI R1, 5 --");
        instr = 16'h0205; // 0000_001_000_000101
        #5;
        check1("alu_src   (1=imm)", alu_src,   1'b1);
        check1("reg_write (1)",     reg_write, 1'b1);
        check1("mem_read  (0)",     mem_read,  1'b0);
        check1("mem_write (0)",     mem_write, 1'b0);
        check1("mem_to_reg(0)",     mem_to_reg,1'b0);
        check1("pc_src    (0)",     pc_src,    1'b0);
        check1("halt      (0)",     halt,      1'b0);

        // ---- ADD R3, R1, R2 ------------------------------------------------
        $display("\n-- ADD R3, R1, R2 --");
        instr = make_instr(4'b0100, 3'd3, 3'd1, 6'd2);
        #5;
        check1("alu_src   (0=reg)", alu_src,   1'b0);
        check1("reg_write (1)",     reg_write, 1'b1);
        check1("mem_read  (0)",     mem_read,  1'b0);
        check1("mem_write (0)",     mem_write, 1'b0);
        check1("pc_src    (0)",     pc_src,    1'b0);
        check1("halt      (0)",     halt,      1'b0);

        // ---- LOAD R2, R1 (load from mem[R1] into R2) -----------------------
        $display("\n-- LOAD R2, R1 --");
        instr = make_instr(4'b0001, 3'd2, 3'd1, 6'd0);
        #5;
        check1("mem_read  (1)",     mem_read,  1'b1);
        check1("mem_write (0)",     mem_write, 1'b0);
        check1("reg_write (1)",     reg_write, 1'b1);
        check1("mem_to_reg(1)",     mem_to_reg,1'b1);
        check1("pc_src    (0)",     pc_src,    1'b0);

        // ---- STORE R1, R2 (store R2 to mem[R1]) ----------------------------
        $display("\n-- STORE R1, R2 --");
        instr = make_instr(4'b0010, 3'd0, 3'd1, 6'd2);
        #5;
        check1("mem_write (1)",     mem_write, 1'b1);
        check1("mem_read  (0)",     mem_read,  1'b0);
        check1("reg_write (0)",     reg_write, 1'b0);
        check1("pc_src    (0)",     pc_src,    1'b0);

        // ---- CMP R1, R2 ----------------------------------------------------
        $display("\n-- CMP R1, R2 --");
        instr = make_instr(4'b1001, 3'd0, 3'd1, 6'd2);
        #5;
        check1("reg_write (0)",     reg_write, 1'b0);  // CMP does NOT write to a register
        check1("mem_read  (0)",     mem_read,  1'b0);
        check1("mem_write (0)",     mem_write, 1'b0);
        check1("pc_src    (0)",     pc_src,    1'b0);

        // ---- JMP 15 --------------------------------------------------------
        $display("\n-- JMP 15 --");
        instr = make_instr(4'b1010, 3'd0, 3'd0, 6'd15);
        #5;
        check1("pc_src    (1)",     pc_src,    1'b1);  // always jump
        check1("reg_write (0)",     reg_write, 1'b0);
        check1("mem_write (0)",     mem_write, 1'b0);
        test_num = test_num + 1;
        if (pc_next === 6'd15) begin
            $display("    PASS [%0d] pc_next = %0d", test_num, pc_next);
            pass_count = pass_count + 1;
        end else begin
            $display("    FAIL [%0d] pc_next: got %0d, expected 15", test_num, pc_next);
            fail_count = fail_count + 1;
        end

        // ---- BEQ 8 with zero=1 (branch taken) ------------------------------
        $display("\n-- BEQ 8 (zero=1, branch taken) --");
        instr = make_instr(4'b1011, 3'd0, 3'd0, 6'd8);
        zero = 1; negative = 0; #5;
        check1("pc_src (1=taken)",  pc_src, 1'b1);

        // ---- BEQ 8 with zero=0 (branch not taken) --------------------------
        $display("\n-- BEQ 8 (zero=0, not taken) --");
        zero = 0; #5;
        check1("pc_src (0=not taken)", pc_src, 1'b0);

        // ---- BNE 8 with zero=0 (branch taken) ------------------------------
        $display("\n-- BNE 8 (zero=0, branch taken) --");
        instr = make_instr(4'b1100, 3'd0, 3'd0, 6'd8);
        zero = 0; negative = 0; #5;
        check1("pc_src (1=taken)",  pc_src, 1'b1);

        // ---- BNE 8 with zero=1 (not taken) ---------------------------------
        $display("\n-- BNE 8 (zero=1, not taken) --");
        zero = 1; #5;
        check1("pc_src (0=not taken)", pc_src, 1'b0);

        // ---- BLT 5 with negative=1 (taken) ---------------------------------
        $display("\n-- BLT 5 (negative=1, taken) --");
        instr = make_instr(4'b1101, 3'd0, 3'd0, 6'd5);
        zero = 0; negative = 1; #5;
        check1("pc_src (1=taken)",  pc_src, 1'b1);

        // ---- BLT 5 with negative=0 (not taken) -----------------------------
        $display("\n-- BLT 5 (negative=0, not taken) --");
        negative = 0; #5;
        check1("pc_src (0=not taken)", pc_src, 1'b0);

        // ---- HALT ----------------------------------------------------------
        $display("\n-- HALT --");
        instr = 16'hF000;
        zero = 0; negative = 0; #5;
        check1("halt      (1)",     halt,      1'b1);
        check1("reg_write (0)",     reg_write, 1'b0);
        check1("mem_write (0)",     mem_write, 1'b0);
        check1("pc_src    (0)",     pc_src,    1'b0);

        // ---- Verify field extraction ----------------------------------------
        $display("\n-- Field extraction --");
        // LOADI R3, 42: opcode=0000, rd=011, rs1=000, imm6=101010
        instr = {4'b0000, 3'b011, 3'b000, 6'b101010};
        #5;
        test_num = test_num + 1;
        if (rd === 3'd3 && rs1 === 3'd0 && imm6 === 6'b101010) begin
            $display("  PASS [%0d] Fields: rd=%0d rs1=%0d imm6=%0d",
                      test_num, rd, rs1, imm6);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [%0d] Fields: rd=%0d rs1=%0d imm6=%0d (expected 3,0,42)",
                      test_num, rd, rs1, imm6);
            fail_count = fail_count + 1;
        end

        // ---- Final ----------------------------------------------------------
        $display("\n============================================");
        $display("  Results: %0d passed, %0d failed (of %0d)",
                  pass_count, fail_count, test_num);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED — Control Unit verified. ✓");
        else
            $display("  SOME TESTS FAILED.");
        $display("============================================");
        $finish;
    end

endmodule
