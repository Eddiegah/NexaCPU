// =============================================================================
// NexaCPU — Register File
// Milestone 2
// =============================================================================
//
// WHAT IS A REGISTER FILE?
// The register file is the CPU's "scratch pad" — a small, extremely fast bank
// of storage locations that sit right next to the ALU. NexaCPU has 8 registers,
// R0–R7, each 16 bits wide. Instructions name their operands by register number
// ("R1", "R3") rather than memory addresses, because registers are faster than
// memory by orders of magnitude.
//
// WHY THIS MILESTONE MATTERS — THE CLOCK:
// This is your first clocked module. Unlike the ALU (which is purely
// combinational — inputs in, outputs out, no memory), a register file has
// state — it remembers values between clock cycles.
//
// The rule: reads are combinational (instant), writes are clocked (synchronized).
// This mirrors real hardware: you can read a register's value at any time,
// but writing a new value only "takes hold" at the rising edge of the clock.
//
// WHY CLOCKED WRITES?
// If writes were combinational, the register value could change mid-cycle while
// the ALU is using it as an input, causing glitches. Clocking the write
// guarantees that a register's value is stable for the entire cycle, and only
// changes at the defined tick boundary. This predictability is what makes
// synchronous digital design manageable.
//
// PORTS:
//   clk        — the clock signal (shared by the whole CPU)
//   rst        — synchronous reset: clears all registers to 0 on next clock edge
//   rd_addr1   — read port 1 address (which register to read for operand A)
//   rd_data1   — read port 1 data output (value of that register)
//   rd_addr2   — read port 2 address (operand B)
//   rd_data2   — read port 2 data output
//   wr_addr    — write address (destination register rd)
//   wr_data    — data to write
//   wr_en      — write enable: 1 = perform write, 0 = do nothing
//
// TWO READ PORTS, ONE WRITE PORT:
// Most ALU instructions need two source registers simultaneously (e.g. ADD R3, R1, R2
// needs R1 and R2 at the same time). So we have two independent read ports.
// We only need one write port because each instruction writes at most one result.
//
// =============================================================================

module register_file (
    input        clk,         // Clock — writes happen on posedge
    input        rst,         // Synchronous reset — all regs → 0

    // Read port 1 (for rs1 / operand A)
    input  [2:0] rd_addr1,    // Which register to read (0–7)
    output [15:0] rd_data1,   // The value in that register

    // Read port 2 (for rs2 / operand B)
    input  [2:0] rd_addr2,    // Which register to read
    output [15:0] rd_data2,   // The value in that register

    // Write port (for rd / result)
    input  [2:0] wr_addr,     // Which register to write
    input  [15:0] wr_data,    // Value to write
    input        wr_en        // 1 = write this cycle, 0 = don't
);

    // -------------------------------------------------------------------------
    // The actual storage: 8 registers, each 16 bits wide
    //
    // In Verilog, a 2D array like this is declared as:
    //   reg [width-1:0] name [0:count-1]
    // Here: 16-bit wide, 8 entries (indices 0–7)
    // -------------------------------------------------------------------------
    reg [15:0] regs [0:7];

    // -------------------------------------------------------------------------
    // Clocked write logic (and reset)
    //
    // This always block fires on every rising clock edge.
    // Two behaviors:
    //   1. Reset: if rst is high, clear every register to 0.
    //   2. Write: if wr_en is high and wr_addr is not R0, write wr_data.
    //
    // WHY SYNCHRONOUS RESET?
    // We check `rst` inside the posedge block rather than adding it to the
    // sensitivity list as `always @(posedge clk or posedge rst)` (asynchronous).
    // Synchronous reset is simpler to reason about and works well for FPGA.
    //
    // R0 IS HARDWIRED TO ZERO:
    // Writing to R0 is silently discarded. Reading R0 always returns 0.
    // This is a classic RISC design choice — having a guaranteed-zero register
    // simplifies many common operations (e.g. `LOADI R0, 5` is a no-op,
    // `SUB Rx, Ry, R0` is a copy, `CMP Rx, R0` checks if Rx is zero).
    // -------------------------------------------------------------------------
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            // Reset: clear all registers. The `for` loop here describes
            // parallel reset logic, not a sequential loop — synthesis will
            // generate simultaneous reset for every register.
            for (i = 0; i < 8; i = i + 1)
                regs[i] <= 16'b0;
        end else if (wr_en && wr_addr != 3'd0) begin
            // Normal write: only if enabled, and not targeting R0
            // `<=` is non-blocking assignment — correct for clocked logic
            regs[wr_addr] <= wr_data;
        end
        // If wr_en=0, nothing changes — the register retains its value.
        // This is the "memory" behavior flip-flops give us.
    end

    // -------------------------------------------------------------------------
    // Combinational read logic
    //
    // Reads are NOT clocked — they are continuous combinational outputs.
    // The moment rd_addr1 changes, rd_data1 updates immediately (same cycle).
    // This is necessary because the CPU needs register values available
    // before the clock edge where it uses them.
    //
    // R0 special case: always reads as 0, regardless of what's stored.
    // -------------------------------------------------------------------------
    assign rd_data1 = (rd_addr1 == 3'd0) ? 16'b0 : regs[rd_addr1];
    assign rd_data2 = (rd_addr2 == 3'd0) ? 16'b0 : regs[rd_addr2];

    // -------------------------------------------------------------------------
    // READ-DURING-WRITE behavior:
    // If you write to a register and read from it in the same clock cycle,
    // the read returns the OLD value (before the write takes effect).
    // This is "write-then-read" latency = 1 cycle, standard for synchronous designs.
    // The control unit is designed with this in mind.
    // -------------------------------------------------------------------------

endmodule
