// =============================================================================
// NexaCPU — Program Counter
// Milestone 3
// =============================================================================
//
// WHAT IS THE PROGRAM COUNTER?
// The Program Counter (PC) is a single register that holds the address of the
// NEXT instruction to fetch. It's the CPU's "bookmark" — it tracks where in
// the program we are.
//
// Every clock cycle, one of three things happens to the PC:
//   1. Reset: PC goes to 0 (start of program)
//   2. Load (jump/branch): PC gets a new address from the instruction
//   3. Increment: PC advances by 1 (fetch the next sequential instruction)
//
// The PC is 6 bits wide — matching our 6-bit immediate field, which means
// programs can be up to 64 instructions long (addresses 0–63).
// That's enough for meaningful programs while keeping the design simple.
//
// =============================================================================

module program_counter (
    input        clk,         // Clock
    input        rst,         // Synchronous reset — PC → 0
    input        load,        // 1 = jump: load `next_pc` into PC
    input  [5:0] next_pc,     // Address to jump to (from instruction)
    output reg [5:0] pc       // Current PC value (fed to instruction memory)
);

    // On every rising clock edge:
    always @(posedge clk) begin
        if (rst)
            pc <= 6'd0;          // Reset: go to address 0
        else if (load)
            pc <= next_pc;       // Jump: take the new address
        else
            pc <= pc + 6'd1;     // Normal: advance to next instruction
    end

    // NOTE: pc + 1 wraps around when it hits 63 → 0 (6-bit overflow).
    // This is fine — HALT stops execution before we reach address 63 in practice.

endmodule
