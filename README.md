# NexaCPU — A Real CPU, Built From Scratch

> A complete CPU designed from first principles: Verilog hardware core → animated browser visualizer → real FPGA silicon.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Setup — Toolchain Installation](#setup--toolchain-installation)
3. [Verilog Basics — What You Need to Know](#verilog-basics--what-you-need-to-know)
4. [The NexaCPU Instruction Set](#the-nexacpu-instruction-set)
5. [Phase 1 — Verilog CPU Core](#phase-1--verilog-cpu-core)
6. [Phase 2 — Animated Visual Simulator](#phase-2--animated-visual-simulator)
7. [Phase 3 — FPGA Hardware](#phase-3--fpga-hardware)
8. [Project Structure](#project-structure)

---

## Project Overview

NexaCPU is a complete, original CPU design built across three layers:

| Layer | What it proves | Where it lives | Status |
|-------|---------------|----------------|--------|
| **Phase 1: Verilog core** | Hardware correctness — this is the real design | `hardware/` | ✅ Complete |
| **Phase 2: Visual simulator** | An accurate, watchable representation of the CPU executing | `visualizer/` | ✅ Live at [visualizer-plum.vercel.app](https://visualizer-plum.vercel.app) |
| **Phase 3: FPGA deployment** | Physical proof — real silicon, real results | `fpga/` | ⏭ Not pursued |

The Verilog is the **source of truth**. The visualizer is a faithful behavioral mirror of it, verified to match instruction-for-instruction.

---

## Setup — Toolchain Installation

### Step 1 — Check your working directory

⚠️ **OneDrive warning**: If your project path contains `OneDrive`, move it before continuing.
Long file paths and OneDrive syncing both cause subtle, hard-to-debug toolchain failures.

Your path should look like `C:\Projects\nexacpu` or similar. ✅

### Step 2 — Install Icarus Verilog (the simulator/compiler)

Icarus Verilog compiles `.v` files and runs simulations. It's free and open-source.

**Option A — Direct installer (recommended for beginners):**
1. Go to: https://bleyer.org/icarus/
2. Download the latest Windows installer (e.g. `iverilog-v12-20220611-x64_setup.exe`)
3. Run the installer. **On the "Select Components" screen, make sure GTKWave is checked** — the installer bundles it.
4. The installer will offer to add Icarus to your PATH automatically — **accept this**.

**Option B — Chocolatey (if you have it):**
```
choco install icarus-verilog
```

### Step 3 — Verify the installation

Open a **new** terminal (PowerShell or CMD) after installing, then run:

```powershell
iverilog -V
gtkwave --version
```

You should see version strings for both. If `iverilog` is not found, the installer's PATH entry hasn't taken effect — try restarting your terminal, or log out and back in.

### Step 4 — Python (for the assembler in Milestone 8)

Python 3.8+ is required. Check with:
```powershell
python --version
```
If not installed: https://www.python.org/downloads/ — check "Add Python to PATH" during setup.

### Step 5 — Node.js (for Phase 2 visualizer)

Node 18+ required. Check with:
```powershell
node --version
```
If not installed: https://nodejs.org/ — use the LTS version.

---

## Verilog Basics — What You Need to Know

> **Read this before looking at any `.v` file.** This is the single biggest conceptual shift coming from software. Getting it wrong leads to bugs that are deeply confusing. Getting it right makes everything else click.

### The fundamental difference: description vs. instruction

In Python or JavaScript, you write a *sequence of instructions* that a processor executes one after another:

```python
# Software: top-to-bottom, one thing at a time
x = 5
y = x + 3
z = y * 2
```

**Verilog does not work like this.** Verilog *describes physical circuits* — wires, logic gates, flip-flops. A circuit doesn't "execute" — it just *exists*, with signals continuously flowing through it. All parts of the circuit are active simultaneously.

Think of it this way:
- Software is a **recipe** — do this, then do that.
- Verilog is a **blueprint** — here's what every component is and how they're connected.

### Concurrency — everything happens at once

In Verilog, when you write multiple `assign` statements or `always` blocks, **they all run in parallel**, not in sequence:

```verilog
// These three lines all describe simultaneous, permanent connections.
// There is no "first" or "second" — they all exist at the same time.
assign sum    = a + b;
assign diff   = a - b;
assign is_eq  = (a == b);
```

This is the **hardest mental shift**. When you look at a Verilog file, don't read it top to bottom like a program. Read it like a schematic — each statement describes a piece of hardware that exists permanently.

### Two types of assignments

**`assign` (combinational logic)** — describes a wire whose value is *continuously computed* from its inputs. The moment any input changes, the output updates instantly (in zero simulated time):

```verilog
wire [7:0] result;
assign result = a + b;  // "result" is permanently wired to the sum of a and b
```

**`always @(posedge clk)` (sequential logic / registers)** — describes a flip-flop. The value only updates on the *rising edge* of the clock signal — that precise moment when the clock transitions from 0 to 1. Between clock edges, the stored value is frozen:

```verilog
always @(posedge clk) begin
    register <= new_value;  // only captures new_value at each clock tick
end
```

The `<=` here is the **non-blocking assignment** — use this inside `always @(posedge clk)` blocks. It means "schedule this update for the end of the current time step" — which is the correct behavior for flip-flops. Using `=` (blocking) in a clocked block is a common beginner mistake that causes subtle bugs.

### What is a clock?

A clock is a signal that oscillates between 0 and 1 at a fixed frequency — imagine a metronome. Every time it ticks (rises from 0 to 1), all the flip-flops in the design capture their new values simultaneously.

This is how a CPU keeps everything synchronized. The ALU computes a result combinationally (instantly), and at the next clock edge, the result gets latched into a register. This "compute then latch" rhythm is the heartbeat of every digital system.

```
Clock:   __|‾|__|‾|__|‾|__|‾|__
          ↑   ↑   ↑   ↑
          registers update here
```

`posedge clk` in Verilog means "at the rising edge of clk" — that upward transition.

### Wires vs. Registers (the naming is confusing — here's the truth)

- `wire` — a physical connection. It has no memory. Its value is determined entirely by whatever is driving it right now.
- `reg` — **despite the name, this does NOT always mean a hardware register/flip-flop.** A `reg` in Verilog just means "a variable that can be assigned inside an `always` block." Whether it actually becomes a flip-flop or just combinational logic depends on *how* you use it.
  - If assigned inside `always @(posedge clk)` → it becomes a flip-flop (has memory)
  - If assigned inside `always @(*)` → it's combinational (no memory, just like `assign`)

This naming confusion trips up almost everyone. Remember: `reg` is a Verilog syntax requirement, not a promise of hardware behavior.

### Module — the basic building block

Everything in Verilog is a `module` — analogous to a function or class in software, but describing a hardware component. Modules have `input` and `output` ports (their interface), and internal logic:

```verilog
module adder(
    input  [7:0] a,       // 8-bit input
    input  [7:0] b,       // 8-bit input
    output [7:0] sum      // 8-bit output
);
    assign sum = a + b;   // permanent connection: sum is always a+b
endmodule
```

Modules are *instantiated* (connected) inside other modules, like placing a chip on a circuit board and wiring it up.

### Testbenches — how we verify the design

A testbench is a special Verilog module with **no ports** — it exists only for simulation. It instantiates the module under test, drives inputs at specific times, and (optionally) checks outputs. Think of it as the testing harness you'd write in software, but for hardware.

```verilog
module adder_tb;          // no ports — testbenches are self-contained
    reg  [7:0] a, b;      // regs so we can drive them
    wire [7:0] sum;       // wire to observe output

    adder uut(.a(a), .b(b), .sum(sum));  // instantiate the adder

    initial begin         // "initial" blocks run once at simulation start
        a = 8'd5; b = 8'd3;
        #10;              // wait 10 time units
        $display("5+3 = %d (expect 8)", sum);
        // ... more test cases
        $finish;
    end
endmodule
```

---

## The NexaCPU Instruction Set

> **This is the contract everything else is built against.** Every module in Phase 1 is designed to implement exactly this ISA. The visualizer in Phase 2 implements exactly this ISA. Read and understand this table before looking at any implementation.

### 8-bit vs. 16-bit: the tradeoff

| | 8-bit | 16-bit |
|--|-------|--------|
| Data width | 8 bits (values 0–255) | 16 bits (values 0–65535) |
| Instruction width | 8 bits — tight, hard to encode immediate values | 16 bits — room for opcode + register fields + immediate in one word |
| Memory addressing | Can only address 256 locations directly | Can address 256+ locations easily with immediate field |
| Complexity | Simpler wiring, but awkward programs | Slightly wider buses, but programs are natural to write |
| Real-world analogy | Like 8080/6502 era | Like early RISC designs |

**Recommendation: 16-bit.** The extra width costs almost nothing in simulation or on an FPGA, and makes the instruction encoding clean and unambiguous. Trying to cram an opcode, two register addresses, *and* an immediate value into 8 bits forces ugly compromises that make the control unit harder to understand, not easier. We're here to learn clearly.

### NexaCPU ISA — 16-bit instructions, 8 registers (R0–R7)

**Instruction format:**

```
 15     12  11   9   8    6   5          0
┌──────────┬───────┬───────┬──────────────┐
│  opcode  │  rd   │  rs1  │  imm6 / rs2  │
│  4 bits  │ 3 bits│ 3 bits│   6 bits     │
└──────────┴───────┴───────┴──────────────┘
```

- **opcode** (bits 15–12): 4-bit operation code — identifies the instruction
- **rd** (bits 11–9): destination register (R0–R7)
- **rs1** (bits 8–6): source register 1
- **imm6 / rs2** (bits 5–0): either a 6-bit immediate value (for LOADI, branches) or lower 3 bits used as rs2 (source register 2) for register-to-register ops

**R0 is hardwired to zero** — reading R0 always returns 0, writes to R0 are discarded. This is a common and useful convention from RISC design.

### Instruction Table

| Mnemonic | Opcode | Format | Operation | Description |
|----------|--------|--------|-----------|-------------|
| `LOADI` | `0000` | `rd, imm6` | `R[rd] ← imm6` | Load a 6-bit immediate value into a register |
| `LOAD` | `0001` | `rd, rs1` | `R[rd] ← Mem[R[rs1]]` | Load from data memory at address in rs1 |
| `STORE` | `0010` | `rs1, rs2` | `Mem[R[rs1]] ← R[rs2]` | Store rs2 into data memory at address in rs1 |
| `MOV` | `0011` | `rd, rs1` | `R[rd] ← R[rs1]` | Copy register rs1 to rd |
| `ADD` | `0100` | `rd, rs1, rs2` | `R[rd] ← R[rs1] + R[rs2]` | Add two registers |
| `SUB` | `0101` | `rd, rs1, rs2` | `R[rd] ← R[rs1] - R[rs2]` | Subtract rs2 from rs1 |
| `AND` | `0110` | `rd, rs1, rs2` | `R[rd] ← R[rs1] & R[rs2]` | Bitwise AND |
| `OR` | `0111` | `rd, rs1, rs2` | `R[rd] ← R[rs1] \| R[rs2]` | Bitwise OR |
| `NOT` | `1000` | `rd, rs1` | `R[rd] ← ~R[rs1]` | Bitwise NOT (ones complement) |
| `CMP` | `1001` | `rs1, rs2` | sets flags only | Compare rs1 and rs2, set Zero/Negative flags |
| `JMP` | `1010` | `imm6` | `PC ← imm6` | Unconditional jump to address |
| `BEQ` | `1011` | `imm6` | `if (Zero) PC ← imm6` | Branch if last CMP was equal (Zero flag set) |
| `BNE` | `1100` | `imm6` | `if (!Zero) PC ← imm6` | Branch if last CMP was not equal |
| `BLT` | `1101` | `imm6` | `if (Neg) PC ← imm6` | Branch if last CMP result was negative |
| `HALT` | `1111` | — | `PC ← PC` | Stop execution |

**Status flags** (set by ALU operations and CMP):
- **Zero (Z)**: set when a result is exactly 0
- **Negative (N)**: set when the MSB of the result is 1 (result is negative in two's complement)
- **Carry (C)**: set when an addition overflows 8 bits / subtraction borrows

### Encoding examples

```
LOADI R1, 5      →  0000 001 000 000101  →  0x0045
ADD   R3, R1, R2 →  0100 011 001 000010  →  0x4C42
CMP   R1, R2     →  1001 000 001 000010  →  0x9042
BNE   12         →  1100 000 000 001100  →  0xC00C
HALT             →  1111 000 000 000000  →  0xF000
```

---

## Phase 1 — Verilog CPU Core

Phase 1 builds the CPU milestone by milestone. Each milestone has its own testbench and must be verified before the next begins.

| Milestone | Component | Status |
|-----------|-----------|--------|
| M1 | ALU | ✅ Verified (22/22 tests) |
| M2 | Register File | ✅ Verified (29/29 tests) |
| M3 | Program Counter & Instruction Memory | ✅ Verified (7/7 tests) |
| M4 | Control Unit | ✅ Verified (41/41 tests) |
| M5 | Data Memory | ✅ Verified (8/8 tests) |
| M6 | Full CPU Integration | ✅ Verified — fetch/decode/execute working |
| M7 | Test Programs | ✅ Verified (17/17 tests across 3 programs) |
| M8 | Assembler | ✅ Complete — output matches hand-assembled programs |

See `hardware/` for all source files and testbenches.

---

## Phase 2 — Animated Visual Simulator

*Not started — begins after Phase 1 is fully verified and confirmed.*

See `visualizer/` for implementation once complete.

---

## Phase 3 — FPGA Hardware

*Phase 3 (FPGA deployment) is not being pursued for this project.*

The two completed phases demonstrate NexaCPU fully:
- **Phase 1** proves the design is hardware-correct — 124 automated tests pass across all 8 milestones
- **Phase 2** makes execution visible and understandable to anyone, deployed live at **https://visualizer-plum.vercel.app**

See `fpga/README.md` for notes on what Phase 3 would have involved.

---

## Project Structure

```
nexacpu/
├── hardware/                   # Phase 1 — Verilog CPU core
│   ├── src/
│   │   ├── alu.v               # Arithmetic/Logic Unit
│   │   ├── register_file.v     # 8 general-purpose registers
│   │   ├── program_counter.v   # PC register + incrementer
│   │   ├── instruction_memory.v # ROM loaded from .mem file
│   │   ├── data_memory.v       # RAM for LOAD/STORE
│   │   ├── control_unit.v      # Instruction decoder
│   │   └── cpu.v               # Top-level integration
│   ├── testbenches/            # One testbench per module
│   ├── programs/               # .mem files (hand-assembled + assembled)
│   └── assembler/
│       └── assemble.py         # Milestone 8 Python assembler
├── visualizer/                 # Phase 2 — Next.js animated simulator
│   ├── app/
│   ├── components/
│   ├── lib/
│   │   └── cpuModel.ts         # Behavioral JS mirror of the Verilog design
│   └── package.json
├── fpga/                       # Phase 3 — FPGA deployment
│   ├── constraints/
│   └── README.md
├── waveforms/                  # GTKWave screenshots & selected .vcd files
├── README.md
└── .gitignore
```
