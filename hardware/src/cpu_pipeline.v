// =============================================================================
// NexaCPU — 2-Stage Pipelined CPU
// =============================================================================
//
// PIPELINE OVERVIEW:
//
//   Stage IF (Instruction Fetch):
//     PC → instruction_memory → if_instr (combinational)
//
//   IF/EX Pipeline Register:
//     Latches if_instr → instr_ex on posedge clk
//     Also latches a "bubble" flag (this slot is a NOP, not a real instruction)
//
//   Stage EX (Execute):
//     Decode instr_ex → control signals
//     Read registers, ALU, data memory, write-back
//     Determine PC_next (branch/jump or PC+1)
//
// HAZARD HANDLING:
//
//   Data hazards (RAW) — FORWARDING:
//     When the instruction in EX is about to write register X, and the
//     instruction entering EX next cycle reads X, forward the EX output
//     directly to the ALU input rather than reading the (stale) register file.
//     We track prev_rd / prev_reg_write / prev_wr_data from last cycle.
//
//   LOAD-use stall:
//     LOAD completes at the end of EX (memory read result available only then).
//     If the following instruction reads the loaded register, we must insert
//     one bubble: freeze the PC, freeze IF/EX, inject NOP into EX for one cycle.
//
//   Control hazards (branches/jumps) — FLUSH:
//     When a taken branch/jump is in EX, the instruction already fetched into
//     IF is wrong. We squash it: inject NOP into IF/EX next cycle.
//     Cost: 1 bubble per taken branch.
//
//   HALT:
//     When HALT enters EX, we freeze the entire pipeline and assert halt output.
//
// =============================================================================

module cpu_pipeline (
    input  clk,
    input  rst,
    output halt,

    output [5:0]  debug_pc,
    output [15:0] debug_instr,
    output [15:0] debug_r1,
    output [15:0] debug_r2,
    output [15:0] debug_r3,
    output [15:0] debug_r4,
    output [15:0] debug_alu_result,
    output [15:0] debug_if_instr,
    output [5:0]  debug_if_pc
);

    parameter MEM_FILE = "hardware/programs/prog_arithmetic.mem";

    // =========================================================================
    // Opcode constants
    // =========================================================================
    localparam OP_LOADI = 4'b0000;
    localparam OP_LOAD  = 4'b0001;
    localparam OP_STORE = 4'b0010;
    localparam OP_MOV   = 4'b0011;
    localparam OP_ADD   = 4'b0100;
    localparam OP_SUB   = 4'b0101;
    localparam OP_AND   = 4'b0110;
    localparam OP_OR    = 4'b0111;
    localparam OP_NOT   = 4'b1000;
    localparam OP_CMP   = 4'b1001;
    localparam OP_JMP   = 4'b1010;
    localparam OP_BEQ   = 4'b1011;
    localparam OP_BNE   = 4'b1100;
    localparam OP_BLT   = 4'b1101;
    localparam OP_HALT  = 4'b1111;
    localparam NOP      = 16'h0000; // LOADI R0,0 — safe no-op (R0 discarded)

    // =========================================================================
    // Registered flags
    // =========================================================================
    reg flag_zero, flag_negative, flag_carry;

    // =========================================================================
    // Halt latch
    // =========================================================================
    reg halted;
    assign halt = halted;

    // =========================================================================
    // IF/EX pipeline register
    // =========================================================================
    reg [15:0] instr_ex;
    reg        bubble_ex;   // 1 = this slot is a NOP/bubble

    // =========================================================================
    // Forwarding state (prev cycle's EX output)
    // =========================================================================
    reg [2:0]  prev_rd;
    reg        prev_reg_write;
    reg [15:0] prev_wr_data;

    // =========================================================================
    // STAGE 1 — IF
    // =========================================================================
    // PC is a simple register here — inlined for stall control
    reg [5:0] if_pc;

    wire [15:0] if_instr;
    instruction_memory #(.MEM_FILE(MEM_FILE)) IMEM (
        .pc(if_pc),
        .instr(if_instr)
    );

    // =========================================================================
    // STAGE 2 — EX: decode instr_ex
    // =========================================================================
    wire [3:0] ex_op   = instr_ex[15:12];
    wire [2:0] ex_rd   = instr_ex[11:9];
    wire [2:0] ex_rs1  = instr_ex[8:6];
    wire [2:0] ex_rs2  = instr_ex[2:0];
    wire [5:0] ex_imm6 = instr_ex[5:0];

    // Active only if this slot carries a real instruction
    wire ex_active = !bubble_ex && !halted;

    // Control signals
    wire ex_reg_write = ex_active && (
        ex_op == OP_LOADI || ex_op == OP_LOAD || ex_op == OP_MOV  ||
        ex_op == OP_ADD   || ex_op == OP_SUB  || ex_op == OP_AND  ||
        ex_op == OP_OR    || ex_op == OP_NOT);

    wire ex_mem_read   = ex_active && (ex_op == OP_LOAD);
    wire ex_mem_write  = ex_active && (ex_op == OP_STORE);
    wire ex_mem_to_reg = (ex_op == OP_LOAD);
    wire ex_is_halt    = ex_active && (ex_op == OP_HALT);

    wire ex_alu_src = (ex_op == OP_LOADI) || (ex_op == OP_LOAD)  ||
                      (ex_op == OP_STORE)  || (ex_op == OP_JMP)   ||
                      (ex_op == OP_BEQ)    || (ex_op == OP_BNE)   ||
                      (ex_op == OP_BLT);

    wire ex_flag_update = ex_active && (
        ex_op == OP_ADD || ex_op == OP_SUB || ex_op == OP_AND ||
        ex_op == OP_OR  || ex_op == OP_NOT || ex_op == OP_CMP);

    // Branch decision reads REGISTERED flags (set by prior instruction)
    wire ex_branch_taken = ex_active && (
        (ex_op == OP_JMP)                          ||
        (ex_op == OP_BEQ && flag_zero     == 1'b1) ||
        (ex_op == OP_BNE && flag_zero     == 1'b0) ||
        (ex_op == OP_BLT && flag_negative == 1'b1));

    wire [5:0] ex_pc_next = ex_imm6;

    // ---- LOAD-use stall detection ------------------------------------------
    // If current EX is LOAD and the instruction now in IF reads ex_rd,
    // we must stall for one cycle.
    wire if_reads_rd = (if_instr[8:6] == ex_rd) || (if_instr[2:0] == ex_rd);
    wire load_use_stall = ex_mem_read && (ex_rd != 3'd0) && if_reads_rd && !bubble_ex;

    // ---- Register file -------------------------------------------------------
    wire [15:0] reg_a_raw, reg_b_raw;

    register_file REGS (
        .clk(clk),
        .rst(rst),
        .rd_addr1(ex_rs1), .rd_data1(reg_a_raw),
        .rd_addr2(ex_rs2), .rd_data2(reg_b_raw),
        .wr_addr(ex_rd),
        .wr_data(ex_wr_data),
        .wr_en(ex_reg_write && !ex_is_halt)
    );

    // ---- Forwarding ----------------------------------------------------------
    // If prev cycle wrote to a register that EX now needs, bypass reg file
    wire fwd_a = prev_reg_write && (prev_rd != 3'd0) && (prev_rd == ex_rs1);
    wire fwd_b = prev_reg_write && (prev_rd != 3'd0) && (prev_rd == ex_rs2);

    wire [15:0] reg_a = fwd_a ? prev_wr_data : reg_a_raw;
    wire [15:0] reg_b = fwd_b ? prev_wr_data : reg_b_raw;

    // ---- ALU -----------------------------------------------------------------
    wire [15:0] alu_b_in = ex_alu_src ? {10'b0, ex_imm6} : reg_b;
    wire [15:0] alu_result;
    wire        alu_zero_comb, alu_neg_comb, alu_carry_comb;

    alu ALU (
        .a(reg_a),
        .b(alu_b_in),
        .op(ex_op),
        .result(alu_result),
        .zero(alu_zero_comb),
        .negative(alu_neg_comb),
        .carry(alu_carry_comb)
    );

    // ---- Data memory ---------------------------------------------------------
    wire [15:0] mem_rd_data;

    data_memory DMEM (
        .clk(clk),
        .addr(reg_a[5:0]),
        .wr_data(reg_b),
        .wr_en(ex_mem_write && !ex_is_halt),
        .rd_en(ex_mem_read),
        .rd_data(mem_rd_data)
    );

    // ---- Write-back mux ------------------------------------------------------
    wire [15:0] ex_wr_data = ex_mem_to_reg ? mem_rd_data : alu_result;

    // =========================================================================
    // CLOCKED STATE — posedge
    // =========================================================================
    always @(posedge clk) begin
        if (rst) begin
            // --- Reset all state ---
            if_pc          <= 6'd0;
            instr_ex       <= NOP;
            bubble_ex      <= 1'b1;
            halted         <= 1'b0;
            flag_zero      <= 1'b0;
            flag_negative  <= 1'b0;
            flag_carry     <= 1'b0;
            prev_rd        <= 3'd0;
            prev_reg_write <= 1'b0;
            prev_wr_data   <= 16'd0;

        end else if (halted) begin
            // Frozen — do nothing once halted
            ;

        end else if (ex_is_halt) begin
            // HALT just completed EX — latch halted flag, freeze everything
            halted    <= 1'b1;
            instr_ex  <= NOP;
            bubble_ex <= 1'b1;

        end else if (load_use_stall) begin
            // LOAD-use stall: inject bubble into EX, freeze PC and IF/EX
            // PC stays at current value (don't advance)
            instr_ex       <= NOP;
            bubble_ex      <= 1'b1;
            // if_pc unchanged — same instruction will re-enter IF next cycle
            // Forwarding state: update from current EX (the LOAD)
            prev_rd        <= ex_rd;
            prev_reg_write <= ex_reg_write;
            prev_wr_data   <= ex_wr_data;

        end else if (ex_branch_taken) begin
            // Taken branch/jump: flush IF (squash wrongly-fetched instruction)
            // Load new PC from branch target
            if_pc          <= ex_pc_next;
            instr_ex       <= NOP;
            bubble_ex      <= 1'b1;
            // Update flags if needed
            if (ex_flag_update) begin
                flag_zero     <= alu_zero_comb;
                flag_negative <= alu_neg_comb;
                flag_carry    <= alu_carry_comb;
            end
            prev_rd        <= ex_rd;
            prev_reg_write <= ex_reg_write;
            prev_wr_data   <= ex_wr_data;

        end else begin
            // Normal advance: PC+1, shift IF instruction into EX
            if_pc          <= if_pc + 6'd1;
            instr_ex       <= if_instr;
            bubble_ex      <= 1'b0;
            // Update flags
            if (ex_flag_update) begin
                flag_zero     <= alu_zero_comb;
                flag_negative <= alu_neg_comb;
                flag_carry    <= alu_carry_comb;
            end
            // Record this cycle's write for forwarding
            prev_rd        <= ex_rd;
            prev_reg_write <= ex_reg_write;
            prev_wr_data   <= ex_wr_data;
        end
    end

    // =========================================================================
    // DEBUG
    // =========================================================================
    assign debug_pc         = if_pc;
    assign debug_instr      = instr_ex;
    assign debug_alu_result = alu_result;
    assign debug_r1         = REGS.regs[1];
    assign debug_r2         = REGS.regs[2];
    assign debug_r3         = REGS.regs[3];
    assign debug_r4         = REGS.regs[4];
    assign debug_if_instr   = if_instr;
    assign debug_if_pc      = if_pc;

endmodule
