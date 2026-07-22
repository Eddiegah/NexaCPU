// =============================================================================
// NexaCPU — Top-Level CPU Integration
// Milestone 6
// =============================================================================
//
// THE FETCH-DECODE-EXECUTE CYCLE:
// Every CPU, from the simplest microcontroller to a modern x86, operates on
// the same fundamental rhythm:
//
//   FETCH:   Read the instruction at the current PC address from instruction memory
//   DECODE:  The control unit interprets the instruction bits into control signals
//   EXECUTE: The ALU computes, registers update, memory is read/written, PC advances
//
// In NexaCPU, this entire cycle happens in ONE clock cycle (single-cycle design).
// More complex CPUs pipeline these stages (different instructions in different
// stages simultaneously), but single-cycle is the clearest way to understand
// the fundamental architecture before adding that complexity.
//
// KEY DESIGN INSIGHT — REGISTERED FLAGS:
// The ALU flags (zero, negative, carry) must be REGISTERED — stored from the
// previous clock cycle. Without this, when a BEQ/BNE/BLT instruction executes,
// the ALU is busy processing the branch instruction's own fields, and the raw
// combinational flags would reflect garbage, not the preceding CMP result.
//
// Solution: a "status register" (flags register) that captures the ALU flags
// at each clock edge whenever an ALU/CMP instruction runs. The control unit
// then reads these stable, registered flags — exactly one cycle behind the
// instruction that set them, which is exactly what we want.
//
// This is why the ISA requires a CMP instruction before every branch:
//   CMP R1, R2   ← sets flags this cycle, flags register captures on posedge
//   BEQ target   ← reads the REGISTERED flags from the CMP — correct!
//
// =============================================================================

module cpu (
    input  clk,
    input  rst,
    output halt,

    // Debug outputs — expose internal state for testbench verification
    output [5:0]  debug_pc,
    output [15:0] debug_instr,
    output [15:0] debug_r1,
    output [15:0] debug_r2,
    output [15:0] debug_r3,
    output [15:0] debug_r4,
    output [15:0] debug_alu_result
);

    // =========================================================================
    // INTERNAL WIRES
    // =========================================================================

    wire [5:0]  pc;
    wire [5:0]  pc_next_jump;
    wire [15:0] instr;

    wire [2:0]  rd, rs1, rs2;
    wire [5:0]  imm6;

    wire [3:0]  alu_op;
    wire        alu_src;
    wire        reg_write;
    wire        mem_to_reg;
    wire        mem_read;
    wire        mem_write;
    wire        pc_src;
    wire        halt_sig;

    wire [15:0] reg_a;
    wire [15:0] reg_b;
    wire [15:0] alu_b;
    wire [15:0] alu_result;
    wire [15:0] mem_rd_data;
    wire [15:0] reg_wr_data;

    // Combinational ALU flag outputs
    wire        alu_zero_comb;
    wire        alu_neg_comb;
    wire        alu_carry_comb;

    // Registered flags — what the control unit actually reads
    reg         flag_zero;
    reg         flag_negative;
    reg         flag_carry;

    // =========================================================================
    // COMPONENTS
    // =========================================================================

    // ---- Program Counter ----------------------------------------------------
    program_counter PC (
        .clk(clk),
        .rst(rst),
        .load(pc_src),
        .next_pc(pc_next_jump),
        .pc(pc)
    );

    // ---- Instruction Memory -------------------------------------------------
    instruction_memory #(.MEM_FILE("hardware/programs/prog_arithmetic.mem")) IMEM (
        .pc(pc),
        .instr(instr)
    );

    // ---- Control Unit -------------------------------------------------------
    // Note: control unit receives REGISTERED flags, not combinational ALU flags
    control_unit CU (
        .instr(instr),
        .zero(flag_zero),           // <-- registered, stable from previous CMP
        .negative(flag_negative),   // <-- registered, stable from previous CMP
        .rd(rd), .rs1(rs1), .rs2(rs2), .imm6(imm6),
        .alu_op(alu_op),
        .alu_src(alu_src),
        .reg_write(reg_write),
        .mem_to_reg(mem_to_reg),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .pc_src(pc_src),
        .pc_next(pc_next_jump),
        .halt(halt_sig)
    );

    // ---- Register File ------------------------------------------------------
    register_file REGS (
        .clk(clk),
        .rst(rst),
        .rd_addr1(rs1), .rd_data1(reg_a),
        .rd_addr2(rs2), .rd_data2(reg_b),
        .wr_addr(rd),
        .wr_data(reg_wr_data),
        .wr_en(reg_write && !halt_sig)
    );

    // ---- ALU B-input Multiplexer -------------------------------------------
    // alu_src=1: use zero-extended immediate (for LOADI, LOAD, etc.)
    // alu_src=0: use register value rs2
    assign alu_b = alu_src ? {10'b0, imm6} : reg_b;

    // ---- ALU ----------------------------------------------------------------
    alu ALU (
        .a(reg_a),
        .b(alu_b),
        .op(alu_op),
        .result(alu_result),
        .zero(alu_zero_comb),
        .negative(alu_neg_comb),
        .carry(alu_carry_comb)
    );

    // ---- Flags Register -----------------------------------------------------
    // Captures ALU flags only when an instruction that affects flags executes.
    // Opcodes that update flags: ADD(0100), SUB(0101), AND(0110), OR(0111),
    //                            NOT(1000), CMP(1001)
    // All other opcodes leave the flags unchanged.
    wire flag_update = (alu_op == 4'b0100) || // ADD
                       (alu_op == 4'b0101) || // SUB
                       (alu_op == 4'b0110) || // AND
                       (alu_op == 4'b0111) || // OR
                       (alu_op == 4'b1000) || // NOT
                       (alu_op == 4'b1001);   // CMP

    always @(posedge clk) begin
        if (rst) begin
            flag_zero     <= 1'b0;
            flag_negative <= 1'b0;
            flag_carry    <= 1'b0;
        end else if (flag_update && !halt_sig) begin
            flag_zero     <= alu_zero_comb;
            flag_negative <= alu_neg_comb;
            flag_carry    <= alu_carry_comb;
        end
        // else: flags unchanged — branches, LOADI, LOAD, STORE, JMP, HALT
        // do not disturb the flags register
    end

    // ---- Data Memory --------------------------------------------------------
    data_memory DMEM (
        .clk(clk),
        .addr(reg_a[5:0]),
        .wr_data(reg_b),
        .wr_en(mem_write && !halt_sig),
        .rd_en(mem_read),
        .rd_data(mem_rd_data)
    );

    // ---- Write-back Multiplexer --------------------------------------------
    assign reg_wr_data = mem_to_reg ? mem_rd_data : alu_result;

    // ---- Halt ---------------------------------------------------------------
    assign halt = halt_sig;

    // ---- Debug outputs ------------------------------------------------------
    assign debug_pc         = pc;
    assign debug_instr      = instr;
    assign debug_alu_result = alu_result;
    assign debug_r1         = REGS.regs[1];
    assign debug_r2         = REGS.regs[2];
    assign debug_r3         = REGS.regs[3];
    assign debug_r4         = REGS.regs[4];

endmodule
