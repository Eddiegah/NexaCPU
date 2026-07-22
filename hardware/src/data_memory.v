// =============================================================================
// NexaCPU — Data Memory (RAM)
// Milestone 5
// =============================================================================
//
// WHAT IS DATA MEMORY?
// This is the RAM — the read/write memory the CPU uses to store and retrieve
// program data (variables, arrays, the stack). Unlike instruction memory
// (which is read-only ROM), data memory can be both read and written.
//
// HARVARD vs VON NEUMANN — WHY SEPARATE MEMORIES:
// In a Harvard architecture, instruction memory and data memory are completely
// separate — different address spaces, different buses, accessed independently.
// Von Neumann uses a single shared memory for everything.
//
// We chose Harvard for these reasons:
//   1. SIMPLICITY: No arbitration needed. The CPU can simultaneously fetch an
//      instruction AND read/write data in the same cycle. With shared memory,
//      only one operation can happen per cycle.
//   2. EDUCATIONAL CLARITY: It makes the datapath diagram cleaner — there's
//      an obvious "instruction bus" and "data bus", which matches how textbooks
//      typically introduce CPUs.
//   3. FPGA PRACTICALITY: Modern FPGAs have dual-port block RAMs that map
//      naturally to Harvard architecture.
//
// SIZE: 64 locations × 16 bits = 128 bytes of data memory.
// Same depth as instruction memory, sufficient for our test programs.
//
// WRITE BEHAVIOR: Synchronous (clocked on posedge)
//   Data written takes effect on the next clock edge — same as registers.
//
// READ BEHAVIOR: Combinational (immediate, like instruction memory)
//   The read result is available within the same cycle it's requested.
//   This is called "asynchronous read" or "transparent read" — it's fine for
//   simulation and for FPGAs that support it (Vivado handles this correctly).
//
// =============================================================================

module data_memory (
    input        clk,          // Clock — writes are synchronous
    input  [5:0] addr,         // 6-bit address (64 locations)
    input  [15:0] wr_data,     // Data to write
    input        wr_en,        // 1 = write this cycle
    input        rd_en,        // 1 = read this cycle (gates the output)
    output [15:0] rd_data      // Data read from memory
);

    // The RAM array: 64 × 16-bit entries
    reg [15:0] mem [0:63];

    // Initialize to zero (important for predictable simulation behavior)
    integer i;
    initial begin
        for (i = 0; i < 64; i = i + 1)
            mem[i] = 16'b0;
    end

    // ---- Synchronous write ------------------------------------------------
    always @(posedge clk) begin
        if (wr_en)
            mem[addr] <= wr_data;
    end

    // ---- Combinational read -----------------------------------------------
    // If rd_en=0, output 0 (not driving anything onto the data bus).
    // If rd_en=1, output the value at `addr`.
    assign rd_data = rd_en ? mem[addr] : 16'b0;

endmodule
