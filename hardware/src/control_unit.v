// =============================================================================
// NexaCPU — Control Unit
// Milestone 4
// =============================================================================
//
// WHAT IS THE CONTROL UNIT?
// The control unit is the "conductor" of the CPU. It takes the 16-bit
// instruction fetched from memory, decodes it, and generates a set of control
// signals that tell every other module what to do this cycle.
//
// It doesn't compute anything itself — it just reads the instruction bits and
// sets a collection of true/false (1-bit) output signals:
//   - Should the ALU add? Or subtract? Or do a bitwise AND?
//   - Should we write the ALU result to a register?
//   - Should we read from data memory? Or write to it?
//   - Should the PC jump to a new address, or just increment?
//
// Think of it as a lookup table: "for instruction opcode X, here are the
// exact switch settings for every other part of the CPU."
//
// WHY THIS IS THE CONCEPTUAL HEART:
// Every design choice made in the ISA (our instruction table) directly
// manifests here. The control unit is where abstract instruction definitions
// become concrete wiring decisions. Understanding this module means
// understanding how the CPU executes programs.
//
// INPUTS:
//   instr    [15:0] — the current instruction from instruction memory
//   zero     [1]    — Zero flag from the ALU (for conditional branches)
//   negative [1]    — Negative flag from the ALU
//
// OUTPUTS (control signals — all combinational):
//   alu_op   [3:0]  — which ALU operation to perform (passed straight through)
//   alu_src  [1]    — ALU B input source: 0=register, 1=immediate value
//   reg_write[1]    — 1 = write ALU result to destination register
//   mem_read [1]    — 1 = read from data memory this cycle
//   mem_write[1]    — 1 = write to data memory this cycle
//   mem_to_reg[1]   — 1 = write memory read result to register (LOAD)
//                     0 = write ALU result to register
//   pc_src   [1]    — 1 = jump (load new PC), 0 = increment PC
//   pc_next  [5:0]  — the jump target address (from instruction immediate field)
//   rd       [2:0]  — destination register address (from instruction)
//   rs1      [2:0]  — source register 1 address
//   rs2      [2:0]  — source register 2 address
//   imm6     [5:0]  — 6-bit immediate value (sign-extended to 16 bits externally)
//   halt     [1]    — 1 = HALT instruction, stop everything
//
// =============================================================================

module control_unit (
    input  [15:0] instr,       // Current instruction
    input         zero,        // ALU Zero flag (for BEQ/BNE)
    input         negative,    // ALU Negative flag (for BLT)

    // Decoded instruction fields (passed to datapath)
    output [2:0]  rd,          // Destination register
    output [2:0]  rs1,         // Source register 1
    output [2:0]  rs2,         // Source register 2
    output [5:0]  imm6,        // 6-bit immediate

    // ALU control
    output [3:0]  alu_op,      // Which ALU operation
    output        alu_src,     // B input: 0=rs2 value, 1=imm6 (zero-extended)

    // Register file control
    output        reg_write,   // 1 = write result to rd
    output        mem_to_reg,  // 1 = result comes from memory (LOAD), 0 = from ALU

    // Data memory control
    output        mem_read,    // 1 = read data memory
    output        mem_write,   // 1 = write data memory

    // PC control
    output        pc_src,      // 1 = jump/branch taken, 0 = PC+1
    output [5:0]  pc_next,     // Jump target address

    // Halt
    output        halt         // 1 = stop the CPU
);

    // -------------------------------------------------------------------------
    // Extract instruction fields — purely combinational bit-slicing
    //
    // This is just wiring: each output is permanently connected to a slice
    // of the instruction register. No logic, just routing.
    // -------------------------------------------------------------------------
    assign rd   = instr[11:9];   // Destination register (bits 11-9)
    assign rs1  = instr[8:6];    // Source register 1   (bits 8-6)
    assign rs2  = instr[2:0];    // Source register 2   (bits 2-0)
    assign imm6 = instr[5:0];    // 6-bit immediate     (bits 5-0)

    // The opcode is the top 4 bits
    wire [3:0] opcode = instr[15:12];

    // The ALU operation code IS the opcode — we designed the ISA this way
    // deliberately, so no translation table is needed. The ALU's op input
    // directly matches the instruction's opcode field.
    assign alu_op = opcode;

    // -------------------------------------------------------------------------
    // Opcode constants (same as in alu.v — duplicated here for readability)
    // -------------------------------------------------------------------------
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

    // -------------------------------------------------------------------------
    // Control signal generation — fully combinational
    //
    // For each control output, we use a continuous assign with a conditional
    // expression. Read each line as: "this signal is 1 when the opcode is X".
    //
    // This is equivalent to a truth table or a ROM lookup:
    //   opcode → set of control bits
    // -------------------------------------------------------------------------

    // ALU source: use the immediate value (not rs2) for LOADI, LOAD, and branches
    // For LOADI: b = imm6 (the value to load)
    // For LOAD:  b = imm6 (could also be rs1-based — we use rs1 for address)
    // For STORE: not strictly needed, but harmless
    assign alu_src = (opcode == OP_LOADI) ||
                     (opcode == OP_LOAD)  ||
                     (opcode == OP_STORE) ||
                     (opcode == OP_JMP)   ||
                     (opcode == OP_BEQ)   ||
                     (opcode == OP_BNE)   ||
                     (opcode == OP_BLT);

    // Register write: 1 for all instructions that produce a result in rd
    // NOT for: STORE (writes memory), CMP (flags only), JMP/branches (no result),
    //          HALT (nothing)
    assign reg_write = (opcode == OP_LOADI) ||
                       (opcode == OP_LOAD)  ||
                       (opcode == OP_MOV)   ||
                       (opcode == OP_ADD)   ||
                       (opcode == OP_SUB)   ||
                       (opcode == OP_AND)   ||
                       (opcode == OP_OR)    ||
                       (opcode == OP_NOT);
    // CMP: no reg write (flags only)
    // STORE, JMP, BEQ, BNE, BLT, HALT: no reg write

    // Result source: LOAD gets its write-back value from memory, not the ALU
    assign mem_to_reg = (opcode == OP_LOAD);

    // Data memory read: only LOAD reads from data memory
    assign mem_read   = (opcode == OP_LOAD);

    // Data memory write: only STORE writes to data memory
    assign mem_write  = (opcode == OP_STORE);

    // PC source: jump if it's JMP, or if it's a conditional branch whose
    // condition is met:
    //   BEQ: branch if Zero=1 (last comparison was equal)
    //   BNE: branch if Zero=0 (last comparison was not equal)
    //   BLT: branch if Negative=1 (last comparison, a < b)
    assign pc_src = (opcode == OP_JMP)                    ||
                    (opcode == OP_BEQ && zero == 1'b1)    ||
                    (opcode == OP_BNE && zero == 1'b0)    ||
                    (opcode == OP_BLT && negative == 1'b1);

    // The jump target is always the imm6 field
    // (for branches AND JMP — our 6-bit ISA uses the immediate as the address)
    assign pc_next = imm6;

    // Halt: stop execution
    assign halt = (opcode == OP_HALT);

endmodule
