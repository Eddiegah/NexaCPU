<div align="center">

<br/>

```
███╗   ██╗███████╗██╗  ██╗ █████╗  ██████╗██████╗ ██╗   ██╗
████╗  ██║██╔════╝╚██╗██╔╝██╔══██╗██╔════╝██╔══██╗██║   ██║
██╔██╗ ██║█████╗   ╚███╔╝ ███████║██║     ██████╔╝██║   ██║
██║╚██╗██║██╔══╝   ██╔██╗ ██╔══██║██║     ██╔═══╝ ██║   ██║
██║ ╚████║███████╗██╔╝ ██╗██║  ██║╚██████╗██║     ╚██████╔╝
╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝      ╚═════╝
```

### A real CPU. Every wire. Every gate. Built from scratch.

<br/>

[![Live Demo](https://img.shields.io/badge/▶%20LIVE%20DEMO-visualizer--plum.vercel.app-38bdf8?style=for-the-badge&logo=vercel&logoColor=white)](https://visualizer-plum.vercel.app)
&nbsp;
[![Tests](https://img.shields.io/badge/✓%20HARDWARE%20TESTS-158%20passing-22c55e?style=for-the-badge)](hardware/)
&nbsp;
[![Pipeline](https://img.shields.io/badge/PIPELINE-2--stage%20·%20forwarding%20·%20hazard%20detection-a78bfa?style=for-the-badge)](hardware/src/cpu_pipeline.v)

<br/>

*16-bit RISC · 8 registers · Harvard architecture · Single-cycle + Pipelined*

<br/>

</div>

---

## What is this?

Most "CPU simulators" are black boxes. This one isn't.

NexaCPU is a **complete, original CPU design** — starting from a blank file and ending with a processor that fetches instructions, decodes them, runs them through a real ALU, reads and writes memory, handles conditional branches, and sorts arrays in silicon logic.

Every module was written by hand in **Verilog HDL**, tested with automated testbenches, assembled into programs using a **custom Python assembler**, and then mirrored in an **animated browser visualizer** so anyone — hardware engineer or not — can watch every instruction execute cycle by cycle.

**[→ Open the live visualizer and see it run](https://visualizer-plum.vercel.app)**

---

## See it in action

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│   PC ──► INSTR MEM ──► CONTROL UNIT ──► REGISTER FILE              │
│    ↑                        │                  │                    │
│    │                        ▼                  ▼                    │
│    │                  (control signals)    ┌── ALU ──┐             │
│    │                                       │         │             │
│    │                                   DATA MEM   FLAGS REG        │
│    │                                       │         │             │
│    └───────────── PC+1 / branch target ────┘         │             │
│                                                  Z · N · C         │
│                                                                     │
│  Single-cycle version: 1 instruction per clock, zero complexity     │
│  Pipelined version:    IF + EX overlap, forwarding, hazard detect   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

The visualizer makes this diagram *alive*. Glowing signals travel along the active paths every cycle. Registers flash when written. Memory highlights when accessed. A plain-English description explains exactly what's happening in that instruction — in real time.

---

## The numbers

| | |
|--|--|
| **158** | automated hardware tests, all passing |
| **8** | Verilog milestones from ALU to full CPU |
| **2** | CPU implementations — single-cycle + 2-stage pipeline |
| **6** | programs running on the hardware — up to and including bubble sort |
| **15** | instructions in the ISA |
| **0** | lines copied from a tutorial |

---

## What's inside

### Phase 1 — The Hardware (`hardware/`)

A complete CPU built milestone by milestone. Each one has its own testbench. Nothing moves forward until the tests pass.

| Milestone | What was built | Tests |
|-----------|---------------|-------|
| M1 | **ALU** — add, subtract, AND, OR, NOT, compare, flags | 22 ✅ |
| M2 | **Register file** — 8 × 16-bit registers, R0 hardwired zero | 29 ✅ |
| M3 | **Program counter + instruction memory** — 6-bit PC, ROM | 7 ✅ |
| M4 | **Control unit** — decodes every instruction into control signals | 41 ✅ |
| M5 | **Data memory** — 64 × 16-bit RAM, synchronous write | 8 ✅ |
| M6 | **Full CPU integration** — all modules wired into one datapath | — ✅ |
| M7 | **Test programs** — arithmetic, countdown loop, Fibonacci | 17 ✅ |
| M8 | **Python assembler** — write assembly, get machine code | ✅ |
| + | **2-stage pipeline** — forwarding, stall, branch flush | 20 ✅ |
| + | **Ambitious programs** — array sum, multiply, bubble sort (×2 CPUs) | 14 ✅ |

**Total: 158 tests. Every single one passes.**

---

### The ISA (Instruction Set Architecture)

The contract everything is built against. 15 instructions, 16-bit encoding.

```
 15    12  11   9  8    6  5         0
┌────────┬───────┬───────┬───────────┐
│ opcode │  rd   │  rs1  │ imm6/rs2  │
│ 4 bits │ 3 bits│ 3 bits│  6 bits   │
└────────┴───────┴───────┴───────────┘
```

| Instruction | What it does |
|------------|-------------|
| `LOADI Rd, imm` | Load a constant (0–63) directly into a register |
| `LOAD Rd, Rs1` | Load a value from data memory at the address in Rs1 |
| `STORE Rs1, Rs2` | Write Rs2 into data memory at the address in Rs1 |
| `MOV Rd, Rs1` | Copy one register to another |
| `ADD / SUB / AND / OR / NOT` | Arithmetic and logic — sets Z, N, C flags |
| `CMP Rs1, Rs2` | Compare two registers (sets flags, no write) |
| `JMP / BEQ / BNE / BLT` | Jump and conditional branches (read registered flags) |
| `HALT` | Stop execution |

**Key design decisions:**
- R0 is hardwired to zero — reads always return 0, writes are discarded
- Flags are **registered** — branches read flags set by the *previous* instruction. This is real hardware behaviour, not a shortcut
- ALU opcode = instruction opcode — the ISA was designed so the control unit needs zero translation

---

### The Pipeline

Two CPU implementations live side by side. Same programs, same results.

```
Single-cycle:
  Cycle:  1       2       3       4
         [I1────][I2────][I3────][I4────]

2-stage pipeline:
  Cycle:  1       2       3       4       5
  IF:    [I1────][I2────][I3────][I4────][I5────]
  EX:            [I1────][I2────][I3────][I4────]
```

**Three hazards, three solutions:**

| Hazard | Problem | Solution |
|--------|---------|----------|
| **Data (RAW)** | SUB reads R3 before ADD has written it | Forwarding — wire EX output directly back to ALU input |
| **LOAD-use** | LOAD result not ready until end of EX | 1-cycle stall — freeze PC + pipeline, inject NOP |
| **Control** | Taken branch — wrong instruction already in IF | Flush — replace IF/EX register with NOP bubble |

Dedicated forwarding test: `LOADI R1,5 / ADD R2,R1,R1 / ADD R3,R2,R1 / HALT`
Without forwarding: R2=0, R3=0. With forwarding: R2=10, R3=15. ✓

---

### The Programs

Six programs prove the CPU is genuinely programmable — not just a demo that runs one fixed sequence.

```
Arithmetic      (5+10)−3=12, 12×2=24, 24 AND 15=8
                Tests: ALU pipeline, flags, every basic operation

Countdown       R1: 5 → 4 → 3 → 2 → 1 → 0, halt when zero
                Tests: CMP + BEQ branch, JMP loop, iteration counting

Fibonacci       F(2)–F(7) stored to mem[2..7] = {1,2,3,5,8,13}
                Tests: STORE, sliding window pattern, nested registers

Array Sum       {10,20,30,40,50,60} stored then summed via LOAD loop
                Tests: STORE+LOAD together, pointer arithmetic → R3=210

Multiply        7 × 9 via repeated addition (how real CPUs without
                hardware multipliers work) → R3=63
                Tests: countdown loop pattern applied to accumulation

Bubble Sort     {5,3,8,1,4} sorted in-memory to {1,3,4,5,8}
                Tests: nested loops, conditional STORE swaps, BLT branch
```

All six run on **both** the single-cycle and pipelined CPUs. Results are identical.

---

### Phase 2 — The Visualizer (`visualizer/`)

**[→ https://visualizer-plum.vercel.app](https://visualizer-plum.vercel.app)**

Built with Next.js · TypeScript · Tailwind CSS · Framer Motion. Fully static — no backend, no server, runs entirely in the browser.

**What makes it different from other CPU simulators:**

The JS model in `visualizer/lib/cpuModel.ts` is not a loose approximation. It implements the exact same registered-flag timing, R0-hardwiring, single-cycle execution, and ALU behaviour as the Verilog. It was verified to produce identical results to the hardware simulation for all 6 programs.

When you click Play, you are watching the **actual hardware design** execute — not a simplified cartoon of it.

**Features:**
- Animated datapath — glowing signal packets travel along whichever wires are active each cycle, using native SVG `<animateMotion>` for cross-browser reliability
- Step mode — one instruction at a time, with plain-English description ("Subtracting R2 (=1) from R1 (=3) → R1 = 2")  
- Live register panel — all 8 registers update in sync, writes flash blue
- Live memory panel — data memory shows writes with address and value
- Speed control — fast / medium / slow
- **Custom program editor** — write your own assembly in the browser, assemble it, watch it run. Includes a full in-browser assembler with line-number error reporting and an ISA reference sidebar

---

## Quick start

**Run the visualizer (no install):**
[→ https://visualizer-plum.vercel.app](https://visualizer-plum.vercel.app)

**Run the hardware simulation:**

```bash
# Install Icarus Verilog: https://bleyer.org/icarus/
git clone https://github.com/Eddiegah/NexaCPU.git
cd NexaCPU

# Run all original tests (124)
iverilog -o hardware/testbenches/cpu_tb.vvp \
    hardware/testbenches/cpu_tb.v \
    hardware/src/alu.v hardware/src/register_file.v \
    hardware/src/program_counter.v hardware/src/instruction_memory.v \
    hardware/src/data_memory.v hardware/src/control_unit.v hardware/src/cpu.v
vvp hardware/testbenches/cpu_tb.vvp
# → ALL TESTS PASSED — Full CPU verified. ✓

# Run ambitious programs on both CPUs (34 more tests)
iverilog -o hardware/testbenches/programs_tb.vvp \
    hardware/testbenches/programs_tb.v \
    hardware/src/alu.v hardware/src/register_file.v \
    hardware/src/program_counter.v hardware/src/instruction_memory.v \
    hardware/src/data_memory.v hardware/src/control_unit.v \
    hardware/src/cpu.v hardware/src/cpu_pipeline.v
vvp hardware/testbenches/programs_tb.vvp
# → ALL TESTS PASSED — Ambitious programs verified. ✓
```

**Write your own program:**

```bash
cd hardware/assembler
python assemble.py ../programs/my_program.asm ../programs/my_program.mem
```

Or use the **in-browser editor** at the live demo — click **✎ Custom**.

**Run the visualizer locally:**

```bash
cd visualizer
npm install
npm run dev
# → http://localhost:3000
```

---

## Project structure

```
NexaCPU/
├── hardware/
│   ├── src/
│   │   ├── alu.v                  Arithmetic/Logic Unit
│   │   ├── register_file.v        8 × 16-bit registers, R0 = 0
│   │   ├── program_counter.v      6-bit PC
│   │   ├── instruction_memory.v   ROM loaded from .mem file
│   │   ├── data_memory.v          64 × 16-bit RAM
│   │   ├── control_unit.v         Instruction decoder
│   │   ├── cpu.v                  Single-cycle integration
│   │   └── cpu_pipeline.v         2-stage pipeline with forwarding
│   ├── testbenches/               One testbench per module + integration
│   ├── programs/                  .asm source + .mem machine code
│   └── assembler/
│       ├── assemble.py            Two-pass Python assembler
│       └── decode.py              Disassembler utility
├── visualizer/
│   ├── components/
│   │   ├── Visualizer.tsx         Top-level layout + state machine
│   │   ├── DatapathDiagram.tsx    SVG datapath + animateMotion packets
│   │   ├── InstructionPanel.tsx   Current instruction + assembly listing
│   │   ├── RegisterPanel.tsx      Live register state with flag badges
│   │   ├── MemoryPanel.tsx        Live data memory
│   │   ├── Controls.tsx           Program selector + playback
│   │   └── ProgramEditor.tsx      In-browser editor + assembler panel
│   └── lib/
│       ├── cpuModel.ts            JS mirror of the Verilog — verified identical
│       └── assembler.ts           Browser-side assembler (TypeScript port)
├── waveforms/                     GTKWave .vcd files from all test runs
└── README.md
```

---

## Toolchain

| Tool | Purpose | Install |
|------|---------|---------|
| **Icarus Verilog** | Compile + simulate `.v` files | [bleyer.org/icarus](https://bleyer.org/icarus/) · `brew install icarus-verilog` |
| **GTKWave** | View `.vcd` waveform files | Bundled with Icarus installer |
| **Python 3.8+** | Run the assembler | [python.org](https://www.python.org/downloads/) |
| **Node.js 18+** | Run the visualizer locally | [nodejs.org](https://nodejs.org/) |

---

<div align="center">

<br/>

**Built from first principles. No shortcuts. No black boxes.**

Every register has a reason. Every wire has a purpose.

<br/>

[![Live Demo](https://img.shields.io/badge/▶%20Open%20Visualizer-38bdf8?style=for-the-badge&logo=vercel&logoColor=white)](https://visualizer-plum.vercel.app)
&nbsp;&nbsp;
[![GitHub](https://img.shields.io/badge/View%20Source-GitHub-24292f?style=for-the-badge&logo=github)](https://github.com/Eddiegah/NexaCPU)

<br/>

</div>
