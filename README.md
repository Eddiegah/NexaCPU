<div align="center">

# NexaCPU

**A real CPU, designed from first principles.**

[![Live Demo](https://img.shields.io/badge/Live%20Demo-visualizer--plum.vercel.app-38bdf8?style=for-the-badge&logo=vercel&logoColor=white)](https://visualizer-plum.vercel.app)
[![Phase 1](https://img.shields.io/badge/Phase%201%20Verilog-124%20tests%20passing-22c55e?style=for-the-badge)](hardware/)
[![Phase 2](https://img.shields.io/badge/Phase%202%20Visualizer-deployed-a78bfa?style=for-the-badge)](https://visualizer-plum.vercel.app)
[![ISA](https://img.shields.io/badge/ISA-16--bit%20RISC%20%C2%B7%2015%20instructions-f59e0b?style=for-the-badge)](#the-nexacpu-instruction-set)

<br/>

*16-bit RISC · 8 registers · Harvard architecture · Single-cycle execution*

</div>

---

NexaCPU is a complete CPU built from scratch — not a tutorial follow-along, not a black-box simulator. The hardware logic is written in Verilog, verified through 124 automated tests, and then faithfully mirrored in an animated browser visualizer where you can watch every instruction execute cycle by cycle.

**[→ Open the live visualizer](https://visualizer-plum.vercel.app)** — select a program, hit Play, and watch the CPU execute. Or click **✎ Custom** to write your own assembly program and run it on the CPU in real time.

---

## What's here

```
┌─────────────────────────────────────────────────────────┐
│                        NexaCPU                          │
│                                                         │
│  Phase 1: Verilog core          Phase 2: Visualizer     │
│  ─────────────────────          ────────────────────    │
│  • ALU                          • Animated datapath     │
│  • Register file (R0–R7)        • Step / play / speed   │
│  • Program counter              • Live register view    │
│  • Instruction memory           • Custom program editor │
│  • Control unit                 • In-browser assembler  │
│  • Data memory                  • Deployed on Vercel    │
│  • Full CPU integration                                 │
│  • Python assembler                                     │
│  124 tests · all passing        visualizer-plum.vercel  │
└─────────────────────────────────────────────────────────┘
```

| | Phase 1 — Verilog | Phase 2 — Visualizer |
|--|-------------------|----------------------|
| **What it is** | The real hardware design in Verilog HDL | An animated browser mirror of Phase 1 |
| **What it proves** | Hardware correctness | That the design is understandable to anyone |
| **Verification** | 124 automated testbench assertions | JS model output verified against Verilog cycle-for-cycle |
| **Location** | `hardware/` | `visualizer/` · [live](https://visualizer-plum.vercel.app) |

> The Verilog is the **source of truth**. The visualizer is a verified behavioral mirror — it produces identical results to the hardware simulation for every program.

---

## Quick start — run the visualizer

No install needed. **[Open it in your browser.](https://visualizer-plum.vercel.app)**

- Choose **Arithmetic**, **Countdown Loop**, or **Fibonacci** from the built-in programs
- Hit **▶ Play** and watch data flow through the datapath in real time
- Or click **✎ Custom** to write and run your own program

---

## Quick start — run the hardware simulation

**Requirements:** [Icarus Verilog](https://bleyer.org/icarus/) (free, includes GTKWave)

```powershell
# Clone
git clone https://github.com/Eddiegah/NexaCPU.git
cd NexaCPU

# Run all tests (from the hardware directory)
cd hardware

# Individual milestones
iverilog -o testbenches/alu_tb.vvp testbenches/alu_tb.v src/alu.v
vvp testbenches/alu_tb.vvp

# Full CPU with all 3 programs
iverilog -o testbenches/cpu_tb.vvp testbenches/cpu_tb.v `
    src/alu.v src/register_file.v src/program_counter.v `
    src/instruction_memory.v src/data_memory.v src/control_unit.v src/cpu.v
vvp testbenches/cpu_tb.vvp
```

Expected output: `ALL TESTS PASSED — Full CPU verified. ✓`

---

## The NexaCPU Instruction Set

15 instructions. Every module in Phase 1 implements this spec exactly. The visualizer mirrors it exactly.

**Instruction word format (16-bit):**
```
 15    12  11   9  8    6  5         0
┌────────┬───────┬───────┬───────────┐
│ opcode │  rd   │  rs1  │ imm6/rs2  │
│ 4 bits │ 3 bits│ 3 bits│  6 bits   │
└────────┴───────┴───────┴───────────┘
```

| Mnemonic | Opcode | Operation | Notes |
|----------|--------|-----------|-------|
| `LOADI` | `0000` | `R[rd] ← imm6` | Immediate range: 0–63 |
| `LOAD`  | `0001` | `R[rd] ← Mem[R[rs1]]` | |
| `STORE` | `0010` | `Mem[R[rs1]] ← R[rs2]` | |
| `MOV`   | `0011` | `R[rd] ← R[rs1]` | |
| `ADD`   | `0100` | `R[rd] ← R[rs1] + R[rs2]` | Sets Z, N, C flags |
| `SUB`   | `0101` | `R[rd] ← R[rs1] - R[rs2]` | Sets Z, N, C flags |
| `AND`   | `0110` | `R[rd] ← R[rs1] & R[rs2]` | Sets Z, N, C flags |
| `OR`    | `0111` | `R[rd] ← R[rs1] \| R[rs2]` | Sets Z, N, C flags |
| `NOT`   | `1000` | `R[rd] ← ~R[rs1]` | Sets Z, N, C flags |
| `CMP`   | `1001` | flags only (rs1 − rs2) | Sets Z, N, C — no register write |
| `JMP`   | `1010` | `PC ← imm6` | Unconditional |
| `BEQ`   | `1011` | `if Zero: PC ← imm6` | Needs prior CMP |
| `BNE`   | `1100` | `if !Zero: PC ← imm6` | Needs prior CMP |
| `BLT`   | `1101` | `if Negative: PC ← imm6` | Needs prior CMP |
| `HALT`  | `1111` | stop | |

**Key design points:**
- **R0 is hardwired to zero** — reads always return 0, writes are silently discarded
- **Flags are registered** — branch instructions read flags set by the *previous* flag-updating instruction (the CMP). This is a real hardware detail, faithfully implemented in both the Verilog and the JS model
- **Harvard architecture** — instruction memory and data memory are completely separate, which simplifies the datapath

---

## Phase 1 — Verilog CPU Core

Built milestone by milestone. Every milestone has its own testbench that must pass before the next begins.

| Milestone | Module | Tests | Result |
|-----------|--------|-------|--------|
| M1 | ALU | 22 | ✅ |
| M2 | Register File | 29 | ✅ |
| M3 | Program Counter + Instruction Memory | 7 | ✅ |
| M4 | Control Unit | 41 | ✅ |
| M5 | Data Memory | 8 | ✅ |
| M6 | Full CPU integration | — | ✅ |
| M7 | Three test programs (arithmetic, countdown loop, Fibonacci) | 17 | ✅ |
| M8 | Python assembler | matches hand-assembled | ✅ |
| **Total** | | **124** | **✅ all passing** |

### Test programs

Three programs run on the integrated CPU and verify the final register/memory state:

**Arithmetic** — `(5 + 10) − 3 = 12`, then `12 × 2 = 24`, then `24 AND 15 = 8`
```asm
LOADI R1, 5   ;  LOADI R2, 10  ;  ADD R3, R1, R2
LOADI R6, 3   ;  SUB R3, R3, R6  ;  ADD R4, R3, R3
LOADI R7, 15  ;  AND R5, R4, R7  ;  HALT
; Result: R3=12, R4=24, R5=8
```

**Countdown loop** — counts R1 from 5 to 0 using `CMP` + `BEQ` + `JMP`
```asm
LOADI R1, 5 ; LOADI R2, 1 ; LOADI R3, 0 ; LOADI R4, 1
loop: CMP R1, R0 ; BEQ done ; SUB R1, R1, R2 ; ADD R3, R3, R4 ; JMP loop
done: HALT
; Result: R1=0, R3=5 (iteration count)
```

**Fibonacci** — computes F(2)–F(7) and stores them to data memory addresses 2–7
```asm
; Result: mem[2]=1, mem[3]=2, mem[4]=3, mem[5]=5, mem[6]=8, mem[7]=13
```

### Running with GTKWave

After running any testbench, a `.vcd` waveform file is saved to `waveforms/`. Open it:
```powershell
gtkwave waveforms\cpu_final.vcd
```
Drag signals into the view: `clk`, `pc`, `instr`, `halt`, and register values. You'll see the Fibonacci program executing — `R1` and `R2` sliding through the Fibonacci sequence, `R4` stepping through memory addresses, `STORE` firing each time a new value is computed.

### Assembler

Write programs in human-readable assembly, assemble to machine code:
```powershell
cd hardware/assembler
python assemble.py ../programs/prog_fibonacci.asm ../programs/out.mem
```

Syntax:
```asm
; Comments with semicolons
; Labels for jump targets
    LOADI R1, 42    ; load immediate
loop:
    SUB   R1, R1, R2
    CMP   R1, R0
    BNE   loop
    HALT
```

---

## Phase 2 — Animated Visual Simulator

**[→ https://visualizer-plum.vercel.app](https://visualizer-plum.vercel.app)**

Built with Next.js 14, TypeScript, Tailwind CSS, and Framer Motion. Fully static — no backend, no server.

### Features

- **Animated datapath** — glowing signals travel along active paths each cycle: registers → ALU → write-back, branches lighting up the flag register, STORE/LOAD activating the data memory paths
- **Step mode** — advance one instruction at a time, read the plain-English description ("Subtracting R2 (=1) from R1 (=3) → R1 = 2")
- **Play mode** — auto-execute with adjustable speed (fast / medium / slow)
- **Live panels** — registers, flags (Z/N/C), and data memory update in sync with every cycle
- **Custom program editor** — write assembly in the browser, assemble it, and run it on the visualizer immediately. Includes:
  - Line-number gutter with red error highlighting
  - Inline error messages with line numbers
  - Hex preview of assembled output
  - Toggleable ISA reference sidebar

### JS model accuracy

The `visualizer/lib/cpuModel.ts` behavioral model is verified to produce identical results to the Verilog simulation:

```
Program 1 Arithmetic: R1=5 R2=10 R3=12 R4=24 R5=8 R7=15  ✓
Program 2 Countdown:  R1=0 R3=5                            ✓
Program 3 Fibonacci:  mem[2..7] = 1,2,3,5,8,13            ✓
```

The Verilog is the source of truth. The JS model matches it because it implements the same logic — registered flags, R0 hardwired to zero, single-cycle execution — not because it was tested against it once and assumed to be correct.

---

## Project Structure

```
NexaCPU/
├── hardware/
│   ├── src/
│   │   ├── alu.v                 # Arithmetic/Logic Unit
│   │   ├── register_file.v       # 8 registers, R0 hardwired zero
│   │   ├── program_counter.v     # 6-bit PC, load/increment
│   │   ├── instruction_memory.v  # ROM, loaded from .mem file
│   │   ├── data_memory.v         # RAM, 64 × 16-bit words
│   │   ├── control_unit.v        # Instruction decoder → control signals
│   │   └── cpu.v                 # Top-level integration
│   ├── testbenches/              # One testbench per module
│   ├── programs/                 # .asm source + .mem machine code
│   └── assembler/
│       └── assemble.py           # Two-pass Python assembler
├── visualizer/
│   ├── app/                      # Next.js app router
│   ├── components/
│   │   ├── Visualizer.tsx        # Top-level layout + state
│   │   ├── DatapathDiagram.tsx   # SVG datapath + Framer Motion animation
│   │   ├── InstructionPanel.tsx  # Current instruction + assembly listing
│   │   ├── RegisterPanel.tsx     # Live register state
│   │   ├── MemoryPanel.tsx       # Live data memory state
│   │   ├── Controls.tsx          # Program selector + playback controls
│   │   └── ProgramEditor.tsx     # Custom program editor panel
│   └── lib/
│       ├── cpuModel.ts           # Behavioral JS mirror of the Verilog
│       └── assembler.ts          # Browser-side assembler (TS port of assemble.py)
├── waveforms/                    # GTKWave .vcd files from Phase 1 testing
├── fpga/                         # Phase 3 notes (not pursued)
└── README.md
```

---

## Toolchain setup (Phase 1)

**Icarus Verilog + GTKWave** (free, Windows/Mac/Linux):
- Windows: https://bleyer.org/icarus/ — the installer bundles GTKWave
- Mac: `brew install icarus-verilog`
- Linux: `sudo apt install iverilog gtkwave`

Verify:
```powershell
iverilog -V
gtkwave --version
```

**Python 3.8+** (for the assembler): https://www.python.org/downloads/

**Node.js 18+** (to run the visualizer locally):
```powershell
cd visualizer
npm install
npm run dev
# open http://localhost:3000
```

---

<div align="center">

Built from first principles. Every wire has a reason.

**[Live demo](https://visualizer-plum.vercel.app) · [Hardware source](hardware/) · [Visualizer source](visualizer/)**

</div>
