/**
 * NexaCPU Browser Assembler
 * TypeScript port of hardware/assembler/assemble.py
 *
 * Takes assembly source text, returns 16-bit instruction words or a list
 * of human-readable errors with line numbers.
 */

// ---------------------------------------------------------------------------
// ISA encoding tables — must match the Verilog opcodes exactly
// ---------------------------------------------------------------------------
const OPCODES: Record<string, number> = {
  LOADI: 0x0, LOAD: 0x1, STORE: 0x2, MOV: 0x3,
  ADD: 0x4, SUB: 0x5, AND: 0x6, OR: 0x7,
  NOT: 0x8, CMP: 0x9, JMP: 0xA, BEQ: 0xB, BNE: 0xC, BLT: 0xD,
  HALT: 0xF,
};

export interface AssemblyError {
  line: number;   // 1-based
  message: string;
}

export type AssemblyResult =
  | { ok: true;  instructions: number[]; source: string }
  | { ok: false; errors: AssemblyError[] };

// ---------------------------------------------------------------------------
// Tokeniser — strips comments, splits label / mnemonic / operands
// ---------------------------------------------------------------------------
interface TokenisedLine {
  lineNum: number;
  label: string | null;
  mnemonic: string | null;
  operands: string[];
}

function tokenise(source: string): TokenisedLine[] {
  const result: TokenisedLine[] = [];
  const lines = source.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    const stripped = raw.split(';')[0].trim();
    if (!stripped) { result.push({ lineNum: i + 1, label: null, mnemonic: null, operands: [] }); continue; }

    let rest = stripped;
    let label: string | null = null;

    // Label: word followed by colon at start of line
    const labelMatch = rest.match(/^([A-Za-z_]\w*):\s*(.*)/);
    if (labelMatch) {
      label = labelMatch[1].toUpperCase();
      rest  = labelMatch[2].trim();
    }

    if (!rest) { result.push({ lineNum: i + 1, label, mnemonic: null, operands: [] }); continue; }

    const parts = rest.split(/\s+/);
    const mnemonic = parts[0].toUpperCase();
    const operandStr = rest.slice(parts[0].length).trim();
    const operands = operandStr ? operandStr.split(',').map(s => s.trim()) : [];

    result.push({ lineNum: i + 1, label, mnemonic, operands });
  }
  return result;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function parseReg(token: string, lineNum: number): { val: number } | AssemblyError {
  const t = token.trim().toUpperCase();
  if (/^R[0-7]$/.test(t)) return { val: parseInt(t[1]) };
  return { line: lineNum, message: `Invalid register '${token}' — use R0–R7` };
}

function parseImm(token: string, labels: Map<string, number>, lineNum: number): { val: number } | AssemblyError {
  const t = token.trim();
  // Hex
  if (/^0x[0-9a-fA-F]+$/i.test(t)) {
    const v = parseInt(t, 16);
    if (v < 0 || v > 63) return { line: lineNum, message: `Immediate 0x${v.toString(16)} out of range (0–63)` };
    return { val: v };
  }
  // Binary
  if (/^0b[01]+$/i.test(t)) {
    const v = parseInt(t.slice(2), 2);
    if (v < 0 || v > 63) return { line: lineNum, message: `Immediate out of range (0–63)` };
    return { val: v };
  }
  // Decimal
  if (/^-?\d+$/.test(t)) {
    const v = parseInt(t);
    if (v < 0 || v > 63) return { line: lineNum, message: `Immediate ${v} out of range (0–63)` };
    return { val: v };
  }
  // Label
  const key = t.toUpperCase();
  if (labels.has(key)) return { val: labels.get(key)! };
  return { line: lineNum, message: `Undefined label or invalid immediate '${token}'` };
}

function isError(x: unknown): x is AssemblyError {
  return typeof x === 'object' && x !== null && 'line' in x && 'message' in x;
}

// ---------------------------------------------------------------------------
// Encoder — mirrors assemble.py encode() exactly
// ---------------------------------------------------------------------------
function encode(
  mnemonic: string,
  operands: string[],
  labels: Map<string, number>,
  lineNum: number,
): number | AssemblyError {
  const op = OPCODES[mnemonic];
  if (op === undefined) return { line: lineNum, message: `Unknown instruction '${mnemonic}'` };

  const need = (n: number) => {
    if (operands.length !== n)
      return { line: lineNum, message: `${mnemonic} requires ${n} operand(s), got ${operands.length}` } as AssemblyError;
    return null;
  };

  switch (mnemonic) {
    case 'HALT': {
      const e = need(0); if (e) return e;
      return op << 12;
    }
    case 'LOADI': {
      const e = need(2); if (e) return e;
      const rd  = parseReg(operands[0], lineNum); if (isError(rd))  return rd;
      const imm = parseImm(operands[1], labels, lineNum); if (isError(imm)) return imm;
      return (op << 12) | (rd.val << 9) | imm.val;
    }
    case 'LOAD':
    case 'MOV':
    case 'NOT': {
      const e = need(2); if (e) return e;
      const rd  = parseReg(operands[0], lineNum); if (isError(rd))  return rd;
      const rs1 = parseReg(operands[1], lineNum); if (isError(rs1)) return rs1;
      return (op << 12) | (rd.val << 9) | (rs1.val << 6);
    }
    case 'STORE': {
      const e = need(2); if (e) return e;
      const rs1 = parseReg(operands[0], lineNum); if (isError(rs1)) return rs1;
      const rs2 = parseReg(operands[1], lineNum); if (isError(rs2)) return rs2;
      return (op << 12) | (rs1.val << 6) | rs2.val;
    }
    case 'ADD':
    case 'SUB':
    case 'AND':
    case 'OR': {
      const e = need(3); if (e) return e;
      const rd  = parseReg(operands[0], lineNum); if (isError(rd))  return rd;
      const rs1 = parseReg(operands[1], lineNum); if (isError(rs1)) return rs1;
      const rs2 = parseReg(operands[2], lineNum); if (isError(rs2)) return rs2;
      return (op << 12) | (rd.val << 9) | (rs1.val << 6) | rs2.val;
    }
    case 'CMP': {
      const e = need(2); if (e) return e;
      const rs1 = parseReg(operands[0], lineNum); if (isError(rs1)) return rs1;
      const rs2 = parseReg(operands[1], lineNum); if (isError(rs2)) return rs2;
      return (op << 12) | (rs1.val << 6) | rs2.val;
    }
    case 'JMP':
    case 'BEQ':
    case 'BNE':
    case 'BLT': {
      const e = need(1); if (e) return e;
      const addr = parseImm(operands[0], labels, lineNum); if (isError(addr)) return addr;
      return (op << 12) | addr.val;
    }
    default:
      return { line: lineNum, message: `Unhandled mnemonic '${mnemonic}'` };
  }
}

// ---------------------------------------------------------------------------
// Two-pass assembler
// ---------------------------------------------------------------------------
export function assemble(source: string): AssemblyResult {
  const tokens = tokenise(source);
  const errors: AssemblyError[] = [];

  // Pass 1 — collect labels
  const labels = new Map<string, number>();
  let addr = 0;
  for (const t of tokens) {
    if (t.label) {
      if (labels.has(t.label)) {
        errors.push({ line: t.lineNum, message: `Duplicate label '${t.label}'` });
      } else {
        labels.set(t.label, addr);
      }
    }
    if (t.mnemonic) addr++;
  }

  if (addr === 0) {
    errors.push({ line: 1, message: 'No instructions found' });
    return { ok: false, errors };
  }
  if (addr > 64) {
    errors.push({ line: tokens[tokens.length - 1].lineNum, message: `Program too long: ${addr} instructions (max 64)` });
    return { ok: false, errors };
  }

  if (errors.length > 0) return { ok: false, errors };

  // Pass 2 — encode
  const instructions: number[] = [];
  for (const t of tokens) {
    if (!t.mnemonic) continue;
    const result = encode(t.mnemonic, t.operands, labels, t.lineNum);
    if (isError(result)) {
      errors.push(result);
    } else {
      instructions.push(result);
    }
  }

  if (errors.length > 0) return { ok: false, errors };
  return { ok: true, instructions, source };
}

// ---------------------------------------------------------------------------
// Quick reference for the editor hint panel
// ---------------------------------------------------------------------------
export const ISA_REFERENCE = [
  { mnemonic: 'LOADI', syntax: 'LOADI Rd, imm',      description: 'Rd = imm (0–63)' },
  { mnemonic: 'LOAD',  syntax: 'LOAD Rd, Rs1',        description: 'Rd = Mem[Rs1]' },
  { mnemonic: 'STORE', syntax: 'STORE Rs1, Rs2',       description: 'Mem[Rs1] = Rs2' },
  { mnemonic: 'MOV',   syntax: 'MOV Rd, Rs1',          description: 'Rd = Rs1' },
  { mnemonic: 'ADD',   syntax: 'ADD Rd, Rs1, Rs2',     description: 'Rd = Rs1 + Rs2' },
  { mnemonic: 'SUB',   syntax: 'SUB Rd, Rs1, Rs2',     description: 'Rd = Rs1 − Rs2' },
  { mnemonic: 'AND',   syntax: 'AND Rd, Rs1, Rs2',     description: 'Rd = Rs1 & Rs2' },
  { mnemonic: 'OR',    syntax: 'OR  Rd, Rs1, Rs2',     description: 'Rd = Rs1 | Rs2' },
  { mnemonic: 'NOT',   syntax: 'NOT Rd, Rs1',           description: 'Rd = ~Rs1' },
  { mnemonic: 'CMP',   syntax: 'CMP Rs1, Rs2',          description: 'Set flags (Rs1 − Rs2), no write' },
  { mnemonic: 'JMP',   syntax: 'JMP label',             description: 'PC = label (unconditional)' },
  { mnemonic: 'BEQ',   syntax: 'BEQ label',             description: 'if Zero: PC = label' },
  { mnemonic: 'BNE',   syntax: 'BNE label',             description: 'if !Zero: PC = label' },
  { mnemonic: 'BLT',   syntax: 'BLT label',             description: 'if Negative: PC = label' },
  { mnemonic: 'HALT',  syntax: 'HALT',                  description: 'Stop execution' },
];
