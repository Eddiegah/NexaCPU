/**
 * NexaCPU Behavioral Model — Phase 2 Visualizer
 *
 * This is a faithful JavaScript/TypeScript mirror of the Phase 1 Verilog design.
 * It implements exactly the same instruction-by-instruction behavior as the
 * verified hardware core, including the registered-flags timing that makes
 * conditional branches work correctly.
 *
 * SOURCE OF TRUTH: The Verilog in hardware/src/ is the hardware-correct design.
 * This model is verified to match it instruction-for-instruction.
 *
 * KEY DESIGN DECISIONS carried over from Verilog:
 * 1. Flags are REGISTERED — they latch at end of each flag-updating instruction.
 *    Branches read flags set by the PREVIOUS instruction (CMP).
 * 2. R0 is hardwired to zero — reads return 0, writes are discarded.
 * 3. ALU immediate is zero-extended (not sign-extended). Range: 0–63.
 * 4. Single-cycle: every call to step() = one complete fetch/decode/execute.
 * 5. MOV uses operand A (rs1), not B — matching the Verilog fix.
 */

// ---------------------------------------------------------------------------
// ISA constants — must match Verilog opcodes exactly
// ---------------------------------------------------------------------------
export const OPCODES = {
  LOADI: 0x0,
  LOAD:  0x1,
  STORE: 0x2,
  MOV:   0x3,
  ADD:   0x4,
  SUB:   0x5,
  AND:   0x6,
  OR:    0x7,
  NOT:   0x8,
  CMP:   0x9,
  JMP:   0xA,
  BEQ:   0xB,
  BNE:   0xC,
  BLT:   0xD,
  HALT:  0xF,
} as const;

export type OpName = keyof typeof OPCODES;

// Reverse lookup: number → mnemonic
const OPCODE_NAMES: Record<number, OpName> = Object.fromEntries(
  Object.entries(OPCODES).map(([k, v]) => [v, k as OpName])
) as Record<number, OpName>;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Which datapath path was active this cycle — used for animation */
export type ActivePath =
  | 'pc-to-imem'
  | 'imem-to-cu'
  | 'cu-to-regs'
  | 'regs-to-alu'
  | 'imm-to-alu'
  | 'alu-to-regs'
  | 'alu-to-flags'
  | 'regs-to-dmem'
  | 'dmem-to-regs'
  | 'alu-to-dmem-addr'
  | 'branch-taken'
  | 'pc-increment';

/** Complete CPU state snapshot — one per cycle, used by visualizer */
export interface CPUState {
  // Program counter
  pc: number;                   // 0–63

  // Instruction word and decoded fields
  instr: number;                // 16-bit instruction
  opcode: number;               // bits [15:12]
  opName: OpName | 'UNKNOWN';   // human-readable mnemonic
  rd: number;                   // bits [11:9]
  rs1: number;                  // bits [8:6]
  rs2: number;                  // bits [2:0]
  imm6: number;                 // bits [5:0]

  // Register file (snapshot after this cycle's write-back)
  regs: number[];               // regs[0..7], 16-bit values

  // Data memory (snapshot after this cycle's write)
  dataMem: number[];            // dataMem[0..63], 16-bit values

  // ALU
  aluA: number;                 // reg_a = R[rs1]
  aluB: number;                 // muxed: immediate or R[rs2]
  aluResult: number;            // 16-bit result

  // Flags — REGISTERED: reflect what was set by the PREVIOUS flag instruction
  // (This is the correct Verilog timing — branch reads flags from prior CMP)
  flagZero: boolean;
  flagNeg: boolean;
  flagCarry: boolean;

  // Control signals
  regWrite: boolean;
  memRead: boolean;
  memWrite: boolean;
  memToReg: boolean;
  aluSrc: boolean;             // true = use immediate
  pcSrc: boolean;              // true = jump/branch taken
  halt: boolean;

  // Explanation text for the "what is happening" panel
  description: string;

  // Which visual paths to animate this cycle
  activePaths: ActivePath[];

  // Which registers changed this cycle (for highlighting)
  changedRegs: number[];

  // Which memory addresses changed this cycle
  changedMem: number[];

  // Cycle number
  cycle: number;
}

// ---------------------------------------------------------------------------
// Instruction programs (the same programs from Phase 1)
// ---------------------------------------------------------------------------
export interface Program {
  name: string;
  description: string;
  source: string;       // Assembly source (for display)
  instructions: number[]; // 16-bit words
}

export const PROGRAMS: Program[] = [
  {
    name: 'Arithmetic',
    description: 'Basic arithmetic: compute (5+10)−3=12, double it to 24, mask to 8',
    source: `LOADI R1, 5         ; R1 = 5
LOADI R2, 10        ; R2 = 10
ADD   R3, R1, R2    ; R3 = 5+10 = 15
LOADI R6, 3         ; R6 = 3
SUB   R3, R3, R6    ; R3 = 15−3 = 12
ADD   R4, R3, R3    ; R4 = 12+12 = 24
LOADI R7, 15        ; R7 = 0x0F (mask)
AND   R5, R4, R7    ; R5 = 24 AND 15 = 8
HALT`,
    instructions: [0x0205, 0x040A, 0x4642, 0x0C03, 0x56C6, 0x48C3, 0x0E0F, 0x6B07, 0xF000],
  },
  {
    name: 'Countdown Loop',
    description: 'Count R1 from 5 down to 0 using CMP + BEQ branch',
    source: `LOADI R1, 5         ; R1 = countdown start
LOADI R2, 1         ; R2 = step
LOADI R3, 0         ; R3 = iteration counter
LOADI R4, 1         ; R4 = 1
loop:
CMP   R1, R0        ; compare R1 to 0
BEQ   done          ; if R1==0, done
SUB   R1, R1, R2    ; R1 −= 1
ADD   R3, R3, R4    ; R3 += 1
JMP   loop          ; repeat
done:
HALT`,
    instructions: [0x0205, 0x0401, 0x0600, 0x0801, 0x9040, 0xB009, 0x5242, 0x46C4, 0xA004, 0xF000],
  },
  {
    name: 'Fibonacci',
    description: 'Compute F(2)–F(7) and store to data memory addresses 2–7',
    source: `LOADI R1, 0         ; F(n-2) = F(0) = 0
LOADI R2, 1         ; F(n-1) = F(1) = 1
LOADI R4, 2         ; mem address = 2
LOADI R5, 8         ; loop limit = 8
LOADI R6, 1         ; address step
loop:
CMP   R4, R5        ; addr == limit?
BEQ   done          ; if equal, done
ADD   R3, R1, R2    ; F(n) = F(n-2)+F(n-1)
STORE R4, R3        ; mem[addr] = F(n)
MOV   R1, R2        ; slide window
MOV   R2, R3
ADD   R4, R4, R6    ; addr++
JMP   loop
done:
HALT`,
    instructions: [0x0200, 0x0401, 0x0802, 0x0A08, 0x0C01, 0x9105, 0xB00D,
                   0x4642, 0x2103, 0x3280, 0x34C0, 0x4906, 0xA005, 0xF000],
  },
];

// ---------------------------------------------------------------------------
// Decode helpers — mirror the Verilog bit-slicing exactly
// ---------------------------------------------------------------------------
function decode(instr: number) {
  return {
    opcode: (instr >> 12) & 0xF,   // bits [15:12]
    rd:     (instr >>  9) & 0x7,   // bits [11:9]
    rs1:    (instr >>  6) & 0x7,   // bits [8:6]
    rs2:     instr        & 0x7,   // bits [2:0]
    imm6:    instr        & 0x3F,  // bits [5:0]
  };
}

/** 16-bit unsigned mask */
const U16 = (n: number) => ((n & 0xFFFF) + 0x10000) % 0x10000;

// ---------------------------------------------------------------------------
// CPU state machine
// ---------------------------------------------------------------------------
export class NexaCPU {
  private instrMem: number[];        // instruction ROM (up to 64 entries)
  private regs: number[];            // register file R0..R7
  private dataMem: number[];         // data RAM 64 × 16-bit
  private pc: number;
  private flagZero: boolean;
  private flagNeg: boolean;
  private flagCarry: boolean;
  private halted: boolean;
  private cycleCount: number;

  constructor(program: Program) {
    this.instrMem = [...program.instructions, ...new Array(64).fill(0)].slice(0, 64);
    this.regs = new Array(8).fill(0);
    this.dataMem = new Array(64).fill(0);
    this.pc = 0;
    this.flagZero = false;
    this.flagNeg = false;
    this.flagCarry = false;
    this.halted = false;
    this.cycleCount = 0;
  }

  get isHalted() { return this.halted; }
  get cycle() { return this.cycleCount; }

  /** Read a register (enforces R0=0) */
  private readReg(r: number): number {
    return r === 0 ? 0 : this.regs[r];
  }

  /** Write a register (enforces R0=hardwired-zero) */
  private writeReg(r: number, val: number): void {
    if (r !== 0) this.regs[r] = U16(val);
  }

  /**
   * Execute one clock cycle — returns the complete state snapshot.
   * If already halted, returns the current frozen state.
   */
  step(): CPUState {
    // Capture pre-step flags (registered: branches see flags from PRIOR cycle)
    const fZ = this.flagZero;
    const fN = this.flagNeg;
    const fC = this.flagCarry;

    if (this.halted) {
      return this.buildState(0, 0, 0, 0, fZ, fN, fC, false, false, false,
        false, false, false, true, 'CPU halted.', [], [], []);
    }

    const instr = this.instrMem[this.pc] ?? 0;
    const { opcode, rd, rs1, rs2, imm6 } = decode(instr);

    // Read registers
    const regA = this.readReg(rs1);   // operand A  (rs1)
    const regB = this.readReg(rs2);   // operand B  (rs2)

    // ALU source mux: use immediate for LOADI, LOAD, STORE, JMP, branches
    const aluSrc = [0x0, 0x1, 0x2, 0xA, 0xB, 0xC, 0xD].includes(opcode);
    const aluB = aluSrc ? imm6 : regB;  // zero-extended immediate

    // ALU (combinational) — mirrors alu.v exactly
    let aluResult = 0;
    let newCarry = false;

    switch (opcode) {
      case 0x0: aluResult = aluB;                            break; // LOADI: pass imm
      case 0x3: aluResult = regA;                            break; // MOV:   pass rs1
      case 0x4: { const s = regA + aluB; newCarry = s > 0xFFFF; aluResult = U16(s); break; } // ADD
      case 0x5: { const s = regA - aluB; newCarry = s < 0;      aluResult = U16(s); break; } // SUB
      case 0x6: aluResult = regA & aluB;                     break; // AND
      case 0x7: aluResult = regA | aluB;                     break; // OR
      case 0x8: aluResult = U16(~regA);                      break; // NOT
      case 0x9: { const s = regA - aluB; newCarry = s < 0; aluResult = U16(s); break; } // CMP
      default:  aluResult = 0;
    }

    const newZero = (aluResult === 0);
    const newNeg  = (aluResult & 0x8000) !== 0;

    // Control signals (mirror control_unit.v)
    const regWrite  = [0x0, 0x1, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8].includes(opcode);
    const memRead   = opcode === 0x1;
    const memWrite  = opcode === 0x2;
    const memToReg  = opcode === 0x1;
    const isHalt    = opcode === 0xF;
    const flagUpdateOps = [0x4, 0x5, 0x6, 0x7, 0x8, 0x9];
    const flagUpdate = flagUpdateOps.includes(opcode);

    // Branch/jump decision — uses PRE-STEP flags (registered, from prior cycle)
    let pcSrc = false;
    switch (opcode) {
      case 0xA: pcSrc = true;         break; // JMP: always
      case 0xB: pcSrc = fZ;           break; // BEQ: if Zero was set
      case 0xC: pcSrc = !fZ;          break; // BNE: if Zero was clear
      case 0xD: pcSrc = fN;           break; // BLT: if Negative was set
    }

    // Memory operations
    const memAddr = regA & 0x3F;       // lower 6 bits of R[rs1]
    const memRdData = memRead ? this.dataMem[memAddr] : 0;

    // Write-back mux
    const wrData = memToReg ? memRdData : aluResult;

    // Which registers / memory changed
    const changedRegs: number[] = [];
    const changedMem: number[] = [];

    // --- Commit state (clock edge) ---
    if (!isHalt) {
      if (regWrite && rd !== 0) {
        this.regs[rd] = U16(wrData);
        changedRegs.push(rd);
      }
      if (memWrite) {
        this.dataMem[memAddr] = U16(regB);
        changedMem.push(memAddr);
      }
      if (flagUpdate) {
        this.flagZero  = newZero;
        this.flagNeg   = newNeg;
        this.flagCarry = newCarry;
      }
      this.pc = pcSrc ? imm6 : (this.pc + 1) & 0x3F;
    } else {
      this.halted = true;
    }

    this.cycleCount++;

    // Active paths for animation
    const paths: ActivePath[] = ['pc-to-imem', 'imem-to-cu'];
    if (aluSrc) paths.push('imm-to-alu'); else paths.push('regs-to-alu');
    if ([0x4,0x5,0x6,0x7,0x8,0x9].includes(opcode)) {
      paths.push('alu-to-flags');
    }
    if (regWrite) paths.push('alu-to-regs');
    if (memWrite) { paths.push('alu-to-dmem-addr'); paths.push('regs-to-dmem'); }
    if (memRead)  { paths.push('dmem-to-regs'); }
    if (pcSrc) paths.push('branch-taken'); else paths.push('pc-increment');

    // Human-readable description
    const desc = buildDescription(opcode, rd, rs1, rs2, imm6, regA, regB, aluResult,
                                  memRdData, fZ, fN, pcSrc, wrData);

    return this.buildState(
      instr, opcode, rd, rs1,
      fZ, fN, fC,
      regWrite, memRead, memWrite, memToReg, aluSrc, pcSrc, isHalt,
      desc, paths, changedRegs, changedMem,
      regA, regB, aluB, aluResult, memRdData
    );
  }

  private buildState(
    instr: number, opcode: number, rd: number, rs1: number,
    fZ: boolean, fN: boolean, fC: boolean,
    regWrite: boolean, memRead: boolean, memWrite: boolean,
    memToReg: boolean, aluSrc: boolean, pcSrc: boolean, halt: boolean,
    description: string, activePaths: ActivePath[],
    changedRegs: number[], changedMem: number[],
    aluA = 0, regB = 0, aluB = 0, aluResult = 0, memRdData = 0
  ): CPUState {
    const { rs2, imm6 } = decode(instr);
    return {
      pc: this.pc,
      instr,
      opcode,
      opName: OPCODE_NAMES[opcode] ?? 'UNKNOWN',
      rd, rs1, rs2, imm6,
      regs: [...this.regs],
      dataMem: [...this.dataMem],
      aluA, aluB, aluResult,
      flagZero: fZ, flagNeg: fN, flagCarry: fC,
      regWrite, memRead, memWrite, memToReg, aluSrc, pcSrc, halt,
      description, activePaths,
      changedRegs, changedMem,
      cycle: this.cycleCount,
    };
  }

  /** Run to completion — returns all intermediate states */
  runAll(maxCycles = 500): CPUState[] {
    const states: CPUState[] = [];
    let guard = 0;
    while (!this.halted && guard++ < maxCycles) {
      states.push(this.step());
    }
    return states;
  }

  reset(program: Program) {
    this.instrMem = [...program.instructions, ...new Array(64).fill(0)].slice(0, 64);
    this.regs = new Array(8).fill(0);
    this.dataMem = new Array(64).fill(0);
    this.pc = 0;
    this.flagZero = false;
    this.flagNeg  = false;
    this.flagCarry = false;
    this.halted = false;
    this.cycleCount = 0;
  }
}

// ---------------------------------------------------------------------------
// Plain-English descriptions per instruction
// ---------------------------------------------------------------------------
function buildDescription(
  opcode: number, rd: number, rs1: number, rs2: number, imm6: number,
  regA: number, regB: number, aluResult: number, memRdData: number,
  fZ: boolean, fN: boolean, pcSrc: boolean, wrData: number
): string {
  const r = (n: number) => `R${n}`;
  switch (opcode) {
    case 0x0: return `Loading value ${imm6} into ${r(rd)}.`;
    case 0x1: return `Loading value ${memRdData} from memory[${regA}] into ${r(rd)}.`;
    case 0x2: return `Storing ${r(rs2)} (= ${regB}) into memory[${regA}].`;
    case 0x3: return `Copying ${r(rs1)} (= ${regA}) → ${r(rd)}.`;
    case 0x4: return `${r(rd)} = ${r(rs1)} + ${r(rs2)} = ${regA} + ${regB} = ${aluResult}.`;
    case 0x5: return `${r(rd)} = ${r(rs1)} − ${r(rs2)} = ${regA} − ${regB} = ${U16(aluResult)}.`;
    case 0x6: return `${r(rd)} = ${r(rs1)} AND ${r(rs2)} = 0x${aluResult.toString(16).toUpperCase()}.`;
    case 0x7: return `${r(rd)} = ${r(rs1)} OR ${r(rs2)} = 0x${aluResult.toString(16).toUpperCase()}.`;
    case 0x8: return `${r(rd)} = NOT ${r(rs1)} = 0x${aluResult.toString(16).toUpperCase()}.`;
    case 0x9: {
      const diff = U16(regA - regB);
      if (regA === regB) return `CMP: ${r(rs1)} = ${r(rs2)} (both ${regA}) → Zero flag SET.`;
      if (regA < regB)  return `CMP: ${r(rs1)} (${regA}) < ${r(rs2)} (${regB}) → Negative flag SET.`;
      return `CMP: ${r(rs1)} (${regA}) > ${r(rs2)} (${regB}) → neither Zero nor Negative.`;
    }
    case 0xA: return `Jumping unconditionally to address ${imm6}.`;
    case 0xB: return pcSrc
      ? `BEQ: Zero flag is SET (last compare was equal) → branching to address ${imm6}.`
      : `BEQ: Zero flag is CLEAR (values were not equal) → continuing to next instruction.`;
    case 0xC: return pcSrc
      ? `BNE: Zero flag is CLEAR → branching to address ${imm6}.`
      : `BNE: Zero flag is SET → not branching.`;
    case 0xD: return pcSrc
      ? `BLT: Negative flag is SET (a < b) → branching to address ${imm6}.`
      : `BLT: Negative flag is CLEAR → not branching.`;
    case 0xF: return 'HALT — program complete. CPU has stopped.';
    default:  return 'Unknown instruction.';
  }
}
