// =============================================================================
// NexaCPU — Instruction Memory (ROM)
// Milestone 3
// =============================================================================
//
// WHAT IS INSTRUCTION MEMORY?
// This is a read-only memory (ROM) that holds the program — the sequence of
// 16-bit instructions the CPU will execute. It's "read-only" because programs
// don't modify themselves; only data memory (Milestone 5) is read/write.
//
// This is the HARVARD ARCHITECTURE choice: instruction memory and data memory
// are completely separate. The alternative (von Neumann) uses one memory for
// both, which requires more careful arbitration. Harvard is simpler for a
// first CPU and is what most embedded/microcontroller architectures use.
//
// HOW PROGRAMS BECOME BINARY:
// The CPU can only understand binary — a sequence of 1s and 0s. A program
// written as assembly ("LOADI R1, 5") needs to be "assembled" into the binary
// encoding from our ISA table. For Milestones 3–7, we hand-assemble programs.
// Milestone 8 automates this with a Python assembler.
//
// The assembled program is stored in a `.mem` file — a plain text file where
// each line is one instruction in hexadecimal. Icarus Verilog can load this
// directly at simulation time using the `$readmemh` system task.
//
// PORTS:
//   pc    [5:0]   — address from the program counter (which instruction to fetch)
//   instr [15:0]  — the instruction at that address (sent to the control unit)
//
// =============================================================================

module instruction_memory (
    input  [5:0]  pc,       // Instruction address (from PC)
    output [15:0] instr     // Instruction bits (to control unit + datapath)
);

    // -------------------------------------------------------------------------
    // The memory array: 64 locations, each 16 bits
    // 64 entries × 16 bits = 128 bytes of program space
    // -------------------------------------------------------------------------
    reg [15:0] mem [0:63];

    // -------------------------------------------------------------------------
    // Load program from file at simulation startup
    //
    // `$readmemh` reads a hex file into the memory array.
    // The path is relative to where you run the simulation from.
    // We use a parameter so the testbench can override the file path.
    //
    // In the full CPU (cpu.v), the top-level will pass the real program file.
    // For isolated testing, we use the test program below.
    // -------------------------------------------------------------------------
    parameter MEM_FILE = "hardware/programs/test_imem.mem";

    initial begin
        $readmemh(MEM_FILE, mem);
    end

    // -------------------------------------------------------------------------
    // Combinational read — instruction is available immediately from PC address
    // Instruction memory reads are not clocked: the PC value goes in,
    // the instruction comes out in the same cycle (within propagation delay).
    // -------------------------------------------------------------------------
    assign instr = mem[pc];

endmodule
