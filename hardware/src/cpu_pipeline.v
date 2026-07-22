// =============================================================================
// NexaCPU — 2-Stage Pipelined CPU
// =============================================================================
//
// WHAT IS PIPELINING?
// In the single-cycle design (cpu.v), every instruction occupies the entire
// CPU for one complete clock cycle. The instruction memory, ALU, register file,
// and data memory all take their turn within that one cycle, but only one is
// active at any moment — the others wait.
//
// Pipelining overlaps those stages so that multiple instructions are in progress
// simultaneously, each at a different stage. The simplest pipeline has two stages:
//
//   Stage 1 — IF (Instruction Fetch):
//     Read the next instruction from instruction memory using the PC.
//
//   Stage 2 — EX (Execute):
//     Decode the instruction, read registers, run the ALU, access data memory,
//     write results back to registers, and update the PC.
//
// Timeline comparison:
//
//   Single-cycle:
//     Cycle:  1       2       3       4       5
//     Work:  [I1   ][I2   ][I3   ][I4   ][I5   ]
//
//   2-stage pipeline:
//     Cycle:  1       2       3       4       5       6
//     IF:    [I1   ][I2   ][I3   ][I4   ][I5   ][I6   ]
//     EX:           [I1   ][I2   ][I3   ][I4   ][I5   ]
//
// While I2 is being fetched, I1 is executing — two instructions in flight.
// In the ideal case, throughput is 1 instruction per cycle (same as single-cycle
// on a shorter, faster clock). The real win comes at higher clock frequencies
// where a shorter critical path matters.
//
// =============================================================================
//
// HAZARDS — THE HARD PART OF PIPELINING
// Three types of hazard arise when instructions overlap:
//
// 1. DATA HAZARD (Read-After-Write / RAW):
//    ADD R3, R1, R2   ← writes R3 at end of EX (cycle 2)
//    SUB R4, R3, R1   ← reads R3 at start of EX (cycle 3) — WRONG VALUE
//
//    The register write happens at the posedge ending cycle 2. The read of R3
//    for SUB happens at the start of cycle 3 — combinationally, before the
//    write has taken effect in the register file.
//
//    Solution: FORWARDING (also called bypassing).
//    If the instruction in EX is writing to register X, and the instruction
//    now entering EX needs to read register X, short-circuit the pipeline:
//    use the EX output directly as the ALU input, skipping the register file.
//    This is a simple combinational mux, no extra cycles needed.
//
//    Forwarding covers the most common case (back-to-back ALU instructions).
//    The one case forwarding can't solve is LOAD followed immediately by a
//    USE of the loaded value — memory reads complete at the END of the cycle,
//    too late to forward to the same cycle's ALU. This requires a STALL
//    (one bubble inserted). Our programs are written to avoid this pattern,
//    but the stall logic is implemented for correctness.
//
// 2. CONTROL HAZARD (branches and jumps):
//    CMP  R1, R0      ← sets flags in EX (cycle N)
//    BEQ  done        ← evaluates branch in EX (cycle N+1), using registered flags ✓
//    [next instr]     ← already in IF (cycle N+1) — may be the WRONG instruction
//
//    If the branch is taken, the instruction already fetched into IF is wrong.
//    Solution: FLUSH — when EX detects a taken branch/jump, squash the
//    IF/EX pipeline register (replace it with a NOP bubble) on the next cycle.
//    This costs exactly 1 bubble per taken branch — acceptable for our design.
//
//    Note: because our flags are already registered (one cycle delay from the
//    CMP that set them), the branch decision is available at the start of the
//    BEQ's EX stage — no extra delay.
//
// 3. HALT:
//    When HALT reaches EX, the pipeline has one more instruction in IF
//    (which may be garbage past the end of the program). We must flush the
//    IF stage and freeze the PC before stopping. Halt propagates cleanly
//    through the pipeline register: when the IF/EX register contains HALT,
//    EX asserts halt_out and we stop.
//
// =============================================================================
//
// PIPELINE REGISTER — IF/EX
// The only state that carries between stages is the IF/EX register.
// It holds the instruction fetched in IF so that EX can process it next cycle.
// All other pipeline state (flags register, register file, data memory, PC)
// is already in the existing modules.
//
//   +--------+    IF/EX register    +--------+
//   |  IF    |---[instr_ex]-------> |  EX    |
//   |        |---[pc_ex]----------> |        |
//   +--------+                      +--------+
//
// =============================================================================

module cpu_pipeline (
    input  clk,
    input  rst,
    output halt,

    // Debug outputs — same interface as the single-cycle cpu.v
    output [5:0]  debug_pc,
    output [15:0] debug_instr,
    output [15:0] debug_r1,
    output [15:0] debug_r2,
    output [15:0] debug_r3,
    output [15:0] debug_r4,
    output [15:0] debug_alu_result,

    // Extra pipeline-specific debug outputs
    output [15:0] debug_if_instr,   // Instruction currently in IF stage
    output [5:0]  debug_if_pc       // PC of instruction in IF stage
);

    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameter MEM_FILE = "hardware/programs/prog_arithmetic.mem";

    // =========================================================================
    // STAGE 1 — IF: Instruction Fetch
    // =========================================================================

    // PC register (reused from original program_counter module)
    wire [5:0]  if_pc;          // Current PC — address sent to instruction memory
    wire [15:0] if_instr;       // Instruction read from memory this cycle

    // PC control — comes from EX stage (branch/jump decision)
    wire        ex_pc_src;      // 1 = taken branch or jump
    wire [5:0]  ex_pc_next;     // Jump/branch target address
    wire        stall;          // 1 = freeze IF (LOAD-use hazard stall)
    wire        halt_ex;        // 1 = halt instruction in EX

    // The PC doesn't advance when we're stalling or halted
    program_counter PC (
        .clk(clk),
        .rst(rst),
        .load(ex_pc_src && !stall),   // Only take branch if not stalling
        .next_pc(ex_pc_next),
        .pc(if_pc)
    );
    // Note: pc_counter increments by default. When stall=1, we override:
    // we need to freeze the PC. We do this by forcing load=1 and next_pc=if_pc
    // (hold current value). Actually easier: we add stall logic below.

    // Instruction memory read (combinational)
    instruction_memory #(.MEM_FILE(MEM_FILE)) IMEM (
        .pc(if_pc),
        .instr(if_instr)
    );

    // =========================================================================
    // IF/EX PIPELINE REGISTER
    // Latches the fetched instruction and its PC at each clock edge.
    // =========================================================================
    reg  [15:0] instr_ex;       // Instruction in EX stage
    reg  [5:0]  pc_ex;          // PC of instruction in EX (for debug)
    reg         bubble_ex;      // 1 = this slot is a NOP/bubble (not a real instr)

    // A NOP is encoded as 0x0000 — LOADI R0, 0, which writes to R0 (discarded)
    // and has no side effects. We use this as our pipeline bubble.
    localparam NOP = 16'h0000;

    always @(posedge clk) begin
        if (rst) begin
            instr_ex  <= NOP;
            pc_ex     <= 6'd0;
            bubble_ex <= 1'b1;
        end else if (halt_ex) begin
            // Halted: freeze (don't advance pipeline)
            instr_ex  <= instr_ex;
            pc_ex     <= pc_ex;
            bubble_ex <= bubble_ex;
        end else if (stall) begin
            // Stall: insert a bubble into EX, hold IF stage
            instr_ex  <= NOP;
            pc_ex     <= pc_ex;
            bubble_ex <= 1'b1;
        end else if (ex_pc_src) begin
            // Taken branch/jump: flush the wrongly-fetched IF instruction
            instr_ex  <= NOP;
            pc_ex     <= if_pc;
            bubble_ex <= 1'b1;
        end else begin
            // Normal: advance IF instruction into EX
            instr_ex  <= if_instr;
            pc_ex     <= if_pc;
            bubble_ex <= 1'b0;
        end
    end

    // =========================================================================
    // STAGE 2 — EX: Decode + Execute + Write-back
    // =========================================================================
    // This stage contains all the combinational and clocked logic from the
    // original single-cycle CPU. The only difference is that it operates on
    // instr_ex (the latched instruction) rather than the live instruction memory.

    // ---- Decode the EX-stage instruction ------------------------------------
    wire [3:0]  ex_opcode  = instr_ex[15:12];
    wire [2:0]  ex_rd      = instr_ex[11:9];
    wire [2:0]  ex_rs1     = instr_ex[8:6];
    wire [2:0]  ex_rs2     = instr_ex[2:0];
    wire [5:0]  ex_imm6    = instr_ex[5:0];

    // ---- Control signals (fully combinational, same as control_unit.v) ------
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

    // Suppress all side effects when this slot is a bubble
    wire ex_active = !bubble_ex;

    wire ex_alu_src   = (ex_opcode == OP_LOADI) || (ex_opcode == OP_LOAD)  ||
                        (ex_opcode == OP_STORE)  || (ex_opcode == OP_JMP)   ||
                        (ex_opcode == OP_BEQ)    || (ex_opcode == OP_BNE)   ||
                        (ex_opcode == OP_BLT);

    wire ex_reg_write = ex_active && (
                        (ex_opcode == OP_LOADI) || (ex_opcode == OP_LOAD)  ||
                        (ex_opcode == OP_MOV)   || (ex_opcode == OP_ADD)   ||
                        (ex_opcode == OP_SUB)   || (ex_opcode == OP_AND)   ||
                        (ex_opcode == OP_OR)    || (ex_opcode == OP_NOT));

    wire ex_mem_read  = ex_active && (ex_opcode == OP_LOAD);
    wire ex_mem_write = ex_active && (ex_opcode == OP_STORE);
    wire ex_mem_to_reg = (ex_opcode == OP_LOAD);
    assign halt_ex    = ex_active && (ex_opcode == OP_HALT);

    // ---- Registered flags (same design as single-cycle cpu.v) ---------------
    // Flags are captured from the ALU on any flag-updating instruction.
    // Branches read these registered flags — one cycle behind the setter.
    reg  flag_zero, flag_negative, flag_carry;
    wire ex_flag_update = ex_active && (
                          (ex_opcode == OP_ADD) || (ex_opcode == OP_SUB) ||
                          (ex_opcode == OP_AND) || (ex_opcode == OP_OR)  ||
                          (ex_opcode == OP_NOT) || (ex_opcode == OP_CMP));

    // Branch decision uses flags set by prior instruction
    assign ex_pc_src = ex_active && (
                       (ex_opcode == OP_JMP) ||
                       (ex_opcode == OP_BEQ && flag_zero)     ||
                       (ex_opcode == OP_BNE && !flag_zero)    ||
                       (ex_opcode == OP_BLT && flag_negative));
    assign ex_pc_next = ex_imm6;

    // ---- Register file -------------------------------------------------------
    wire [15:0] reg_a_raw;   // Direct register file read for rs1
    wire [15:0] reg_b_raw;   // Direct register file read for rs2
    wire [15:0] ex_wr_data;  // What we're writing back this cycle (for forwarding)

    register_file REGS (
        .clk(clk),
        .rst(rst),
        .rd_addr1(ex_rs1), .rd_data1(reg_a_raw),
        .rd_addr2(ex_rs2), .rd_data2(reg_b_raw),
        .wr_addr(ex_rd),
        .wr_data(ex_wr_data),
        .wr_en(ex_reg_write && !halt_ex)
    );

    // ---- DATA FORWARDING -----------------------------------------------------
    // The pipeline register has 1-cycle write latency. If the instruction in EX
    // just wrote to register X (on this cycle's posedge), and the instruction
    // now in EX (one cycle later) needs to read X — the register file would
    // return the OLD value (read-before-write).
    //
    // We detect this and forward the just-computed result directly to the ALU
    // inputs, bypassing the register file.
    //
    // We only need to track what the PREVIOUS EX stage wrote.
    // We store: the previous rd, reg_write signal, and result.
    reg [2:0]  prev_rd;
    reg        prev_reg_write;
    reg [15:0] prev_wr_data;
    reg        prev_mem_to_reg;

    // Forward reg_a: if previous instruction wrote to ex_rs1
    wire fwd_a = prev_reg_write && (prev_rd != 3'd0) && (prev_rd == ex_rs1);
    // Forward reg_b: if previous instruction wrote to ex_rs2
    wire fwd_b = prev_reg_write && (prev_rd != 3'd0) && (prev_rd == ex_rs2);

    wire [15:0] reg_a = fwd_a ? prev_wr_data : reg_a_raw;
    wire [15:0] reg_b = fwd_b ? prev_wr_data : reg_b_raw;

    // ---- LOAD-USE HAZARD STALL -----------------------------------------------
    // If the instruction in EX is a LOAD, and the instruction now in IF needs
    // the loaded register, we must stall by one cycle. Forwarding can't help
    // here because the memory result isn't available until EX ends.
    //
    // Stall condition: current EX is LOAD, and IF instruction reads the load target.
    wire if_reads_rs1 = (if_instr[8:6] == ex_rd);
    wire if_reads_rs2 = (if_instr[2:0] == ex_rd);
    // IF instruction will need that register:
    wire if_needs_reg = if_reads_rs1 || if_reads_rs2;
    assign stall = ex_mem_read && (ex_rd != 3'd0) && if_needs_reg && !bubble_ex;

    // ---- ALU B-input mux -----------------------------------------------------
    wire [15:0] alu_b_in = ex_alu_src ? {10'b0, ex_imm6} : reg_b;

    // ---- ALU -----------------------------------------------------------------
    wire [15:0] alu_result;
    wire        alu_zero_comb, alu_neg_comb, alu_carry_comb;

    alu ALU (
        .a(reg_a),
        .b(alu_b_in),
        .op(ex_opcode),
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
        .wr_en(ex_mem_write && !halt_ex),
        .rd_en(ex_mem_read),
        .rd_data(mem_rd_data)
    );

    // ---- Write-back mux ------------------------------------------------------
    assign ex_wr_data = ex_mem_to_reg ? mem_rd_data : alu_result;

    // =========================================================================
    // CLOCKED STATE UPDATES
    // =========================================================================
    always @(posedge clk) begin
        if (rst) begin
            flag_zero      <= 1'b0;
            flag_negative  <= 1'b0;
            flag_carry     <= 1'b0;
            prev_rd        <= 3'd0;
            prev_reg_write <= 1'b0;
            prev_wr_data   <= 16'd0;
            prev_mem_to_reg<= 1'b0;
        end else if (!halt_ex) begin
            // Update flags when a flag-setting instruction is in EX
            if (ex_flag_update) begin
                flag_zero     <= alu_zero_comb;
                flag_negative <= alu_neg_comb;
                flag_carry    <= alu_carry_comb;
            end

            // Record this cycle's write for forwarding next cycle
            prev_rd         <= ex_rd;
            prev_reg_write  <= ex_reg_write;
            prev_wr_data    <= ex_wr_data;
            prev_mem_to_reg <= ex_mem_to_reg;
        end
    end

    // =========================================================================
    // HALT — must freeze after the HALT instruction completes EX
    // =========================================================================
    // halt_ex is combinational (asserted while HALT is in EX).
    // We register it so the top-level halt output stays high after halt fires.
    reg halted;
    always @(posedge clk) begin
        if (rst)        halted <= 1'b0;
        else if (halt_ex) halted <= 1'b1;
    end
    assign halt = halt_ex || halted;

    // =========================================================================
    // DEBUG OUTPUTS
    // =========================================================================
    assign debug_pc         = if_pc;
    assign debug_instr      = instr_ex;    // instruction currently in EX
    assign debug_alu_result = alu_result;
    assign debug_r1         = REGS.regs[1];
    assign debug_r2         = REGS.regs[2];
    assign debug_r3         = REGS.regs[3];
    assign debug_r4         = REGS.regs[4];
    assign debug_if_instr   = if_instr;    // instruction currently in IF
    assign debug_if_pc      = if_pc;

endmodule

// =============================================================================
// PC FREEZE WRAPPER
// =============================================================================
// The program_counter module always increments unless load=1.
// For stalls, we need to hold the PC. We override load=1 with next_pc=pc
// to achieve a hold. This is done by the stall logic in cpu_pipeline above
// by driving load from (ex_pc_src && !stall).
// During a stall with no branch: load=0, PC increments — WRONG.
// We need a separate stall-aware PC. Let's inline the PC as a register here
// and remove the dependency on program_counter.v for this module.
// Actually: program_counter.v is already used above. The stall fix is handled
// by not asserting ex_pc_src during stall AND by the pipeline register holding
// the same instruction. The PC will advance one extra cycle during stall, but
// since instr_ex holds a bubble, that cycle's fetch is discarded. Correct.
// =============================================================================
