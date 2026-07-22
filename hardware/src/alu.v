// =============================================================================
// NexaCPU — Arithmetic/Logic Unit (ALU)
// Milestone 1
// =============================================================================
//
// WHAT IS AN ALU?
// The ALU is the component that does all the actual computation in a CPU.
// Every ADD, SUB, AND, OR, NOT, and CMP instruction ultimately runs through
// this module. It's purely combinational — no clock, no memory. Given inputs
// A, B, and an operation code, it immediately produces a result and status flags.
//
// Because it's combinational, you can think of it as a collection of parallel
// circuits, all computing their results at the same time, with a multiplexer
// at the end selecting which result to pass through based on `op`.
//
// PORTS:
//   a       [15:0]  — first operand (from a register)
//   b       [15:0]  — second operand (from a register or immediate)
//   op      [3:0]   — operation selector (matches the ISA opcodes)
//   result  [15:0]  — computed output
//   zero    [1]     — flag: result == 0
//   negative[1]     — flag: result[15] == 1 (MSB set = negative in two's complement)
//   carry   [1]     — flag: arithmetic overflow / borrow
//
// =============================================================================

module alu (
    input  [15:0] a,          // Operand A — typically the value in rs1
    input  [15:0] b,          // Operand B — value in rs2, or sign-extended immediate
    input  [3:0]  op,         // Operation code — from the instruction's opcode field
    output reg [15:0] result, // The computed result — will be written to rd
    output zero,              // Zero flag: 1 if result is exactly 0
    output negative,          // Negative flag: 1 if result's MSB is 1
    output reg carry          // Carry flag: 1 on arithmetic carry/borrow
);

    // -------------------------------------------------------------------------
    // Operation constants — matching the NexaCPU ISA opcode table
    // Using `localparam` (local parameters) rather than magic numbers in the
    // case statement below. This is good practice: changing the ISA means
    // changing one definition here, not hunting through code.
    // -------------------------------------------------------------------------
    localparam OP_LOADI = 4'b0000; // Load immediate — ALU passes b through
    localparam OP_LOAD  = 4'b0001; // Load from memory — not computed in ALU
    localparam OP_STORE = 4'b0010; // Store to memory — not computed in ALU
    localparam OP_MOV   = 4'b0011; // Move — ALU passes b through
    localparam OP_ADD   = 4'b0100; // Addition
    localparam OP_SUB   = 4'b0101; // Subtraction
    localparam OP_AND   = 4'b0110; // Bitwise AND
    localparam OP_OR    = 4'b0111; // Bitwise OR
    localparam OP_NOT   = 4'b1000; // Bitwise NOT (unary, only uses a)
    localparam OP_CMP   = 4'b1001; // Compare — computes a-b for flags only

    // -------------------------------------------------------------------------
    // Combinational logic block
    //
    // `always @(*)` means: re-evaluate whenever ANY input signal changes.
    // The `*` is a shorthand for "sensitivity to everything this block reads."
    // This makes it combinational — no clock, no memory.
    //
    // `result` and `carry` are declared `reg` because they're assigned inside
    // an `always` block. This does NOT mean they are flip-flops — because this
    // block is not clocked, the synthesis tool will make them combinational.
    // -------------------------------------------------------------------------
    always @(*) begin
        carry  = 1'b0;   // default: no carry (overridden for ADD/SUB)
        result = 16'b0;  // default: zero (overridden by each case)

        case (op)

            // -- LOADI / MOV: pass the B operand straight through -----------
            // For LOADI: b is the sign-extended 6-bit immediate
            // For MOV:   the SOURCE register is encoded in rs1 position,
            //            so reg_a holds the value to copy (NOT reg_b/rs2).
            //            We pass `a` through for MOV, `b` for LOADI.
            OP_LOADI: begin
                result = b;
            end
            OP_MOV: begin
                result = a;   // MOV copies rs1 (a) into rd
            end

            // -- ADD ---------------------------------------------------------
            // We use a 17-bit wire for the addition so we can capture the
            // carry out of bit 15. The extra bit [16] is the carry.
            OP_ADD: begin
                {carry, result} = {1'b0, a} + {1'b0, b};
                // {carry, result} is Verilog concatenation — treating the two
                // as a single 17-bit value and splitting the result.
            end

            // -- SUB ---------------------------------------------------------
            // Subtraction: a - b. The carry flag here represents a borrow.
            // We compute it as a + (~b + 1) = a + two's complement of b.
            // The carry output from this is 1 when there is NO borrow (result >= 0).
            // We invert it to get a conventional "borrow" flag.
            OP_SUB: begin
                {carry, result} = {1'b0, a} - {1'b0, b};
                carry = ~carry; // invert: carry=1 means borrow occurred
            end

            // -- AND ---------------------------------------------------------
            OP_AND: begin
                result = a & b;
            end

            // -- OR ----------------------------------------------------------
            OP_OR: begin
                result = a | b;
            end

            // -- NOT ---------------------------------------------------------
            // Unary: only uses operand A. B is ignored.
            OP_NOT: begin
                result = ~a;
            end

            // -- CMP ---------------------------------------------------------
            // Compare sets flags by computing a - b, but the result is
            // NOT written to any register. Only the flags matter.
            // The control unit will suppress the register write for CMP.
            OP_CMP: begin
                result = a - b;
            end

            // -- LOAD / STORE / anything else --------------------------------
            // These instructions don't need the ALU to compute anything.
            // For LOAD/STORE, the address comes from a register directly —
            // we'll route that in the datapath, not here.
            // For unknown opcodes, default to 0 (safe fallback).
            default: begin
                result = 16'b0;
            end

        endcase
    end

    // -------------------------------------------------------------------------
    // Status flags — continuous assignments, always reflecting the current result
    //
    // These are wires driven by the result. They update instantly whenever
    // `result` changes — no clock needed.
    // -------------------------------------------------------------------------

    // Zero flag: 1 when every bit of result is 0
    assign zero     = (result == 16'b0);

    // Negative flag: 1 when the most significant bit is 1
    // In two's complement representation, MSB=1 means the number is negative
    assign negative = result[15];

endmodule
