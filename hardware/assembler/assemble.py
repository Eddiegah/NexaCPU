#!/usr/bin/env python3
"""
NexaCPU Assembler — Milestone 8
Converts NexaCPU assembly source (.asm) to hex machine code (.mem)

USAGE:
    python assemble.py <input.asm> <output.mem>
    python assemble.py programs/my_prog.asm programs/my_prog.mem

ASSEMBLY SYNTAX:
    - One instruction per line
    - Comments start with ; (can appear on same line as instruction)
    - Blank lines are ignored
    - Labels: a word followed by colon, on its own line or before an instruction
      e.g.  loop:  CMP R1, R0

INSTRUCTIONS:
    LOADI  Rd, imm     ; Rd = imm (0-63)
    LOAD   Rd, Rs1     ; Rd = Mem[Rs1]
    STORE  Rs1, Rs2    ; Mem[Rs1] = Rs2
    MOV    Rd, Rs1     ; Rd = Rs1
    ADD    Rd, Rs1, Rs2
    SUB    Rd, Rs1, Rs2
    AND    Rd, Rs1, Rs2
    OR     Rd, Rs1, Rs2
    NOT    Rd, Rs1
    CMP    Rs1, Rs2
    JMP    label/imm
    BEQ    label/imm
    BNE    label/imm
    BLT    label/imm
    HALT

REGISTERS: R0-R7 (R0 is hardwired to zero)

EXAMPLE (.asm file):
    ; Count from 5 down to 0
        LOADI R1, 5
        LOADI R2, 1
    loop:
        CMP   R1, R0
        BEQ   done
        SUB   R1, R1, R2
        JMP   loop
    done:
        HALT
"""

import sys
import re
from pathlib import Path

# ---------------------------------------------------------------------------
# Opcode table
# ---------------------------------------------------------------------------
OPCODES = {
    'LOADI': 0b0000,
    'LOAD':  0b0001,
    'STORE': 0b0010,
    'MOV':   0b0011,
    'ADD':   0b0100,
    'SUB':   0b0101,
    'AND':   0b0110,
    'OR':    0b0111,
    'NOT':   0b1000,
    'CMP':   0b1001,
    'JMP':   0b1010,
    'BEQ':   0b1011,
    'BNE':   0b1100,
    'BLT':   0b1101,
    'HALT':  0b1111,
}

def parse_reg(token: str, context: str) -> int:
    """Parse 'R0'-'R7' and return register number 0-7."""
    token = token.strip().upper()
    if not re.match(r'^R[0-7]$', token):
        raise ValueError(f"Invalid register '{token}' in: {context}")
    return int(token[1])

def parse_imm(token: str, labels: dict, context: str) -> int:
    """Parse an immediate value or label reference. Returns 0-63."""
    token = token.strip()
    # Try numeric first
    try:
        if token.startswith('0x') or token.startswith('0X'):
            val = int(token, 16)
        elif token.startswith('0b') or token.startswith('0B'):
            val = int(token, 2)
        else:
            val = int(token)
        if not (0 <= val <= 63):
            raise ValueError(f"Immediate {val} out of range (0-63) in: {context}")
        return val
    except ValueError as e:
        if 'out of range' in str(e):
            raise
        pass
    # Try label
    token_upper = token.upper()
    if token_upper in labels:
        return labels[token_upper]
    if token in labels:
        return labels[token]
    raise ValueError(f"Undefined label or invalid immediate '{token}' in: {context}")

def encode(mnemonic: str, operands: list, labels: dict, line: str) -> int:
    """Encode one instruction to a 16-bit integer."""
    op = OPCODES[mnemonic]

    if mnemonic == 'HALT':
        return (op << 12)

    if mnemonic == 'LOADI':
        # LOADI Rd, imm6
        if len(operands) != 2:
            raise ValueError(f"LOADI needs 2 operands: {line}")
        rd  = parse_reg(operands[0], line)
        imm = parse_imm(operands[1], labels, line)
        return (op << 12) | (rd << 9) | imm

    if mnemonic in ('LOAD', 'MOV', 'NOT'):
        # LOAD Rd, Rs1  /  MOV Rd, Rs1  /  NOT Rd, Rs1
        if len(operands) != 2:
            raise ValueError(f"{mnemonic} needs 2 operands: {line}")
        rd  = parse_reg(operands[0], line)
        rs1 = parse_reg(operands[1], line)
        return (op << 12) | (rd << 9) | (rs1 << 6)

    if mnemonic == 'STORE':
        # STORE Rs1, Rs2  (mem[Rs1] = Rs2)
        if len(operands) != 2:
            raise ValueError(f"STORE needs 2 operands: {line}")
        rs1 = parse_reg(operands[0], line)
        rs2 = parse_reg(operands[1], line)
        return (op << 12) | (rs1 << 6) | rs2

    if mnemonic in ('ADD', 'SUB', 'AND', 'OR'):
        # op Rd, Rs1, Rs2
        if len(operands) != 3:
            raise ValueError(f"{mnemonic} needs 3 operands: {line}")
        rd  = parse_reg(operands[0], line)
        rs1 = parse_reg(operands[1], line)
        rs2 = parse_reg(operands[2], line)
        return (op << 12) | (rd << 9) | (rs1 << 6) | rs2

    if mnemonic == 'CMP':
        # CMP Rs1, Rs2 (no destination register)
        if len(operands) != 2:
            raise ValueError(f"CMP needs 2 operands: {line}")
        rs1 = parse_reg(operands[0], line)
        rs2 = parse_reg(operands[1], line)
        return (op << 12) | (rs1 << 6) | rs2

    if mnemonic in ('JMP', 'BEQ', 'BNE', 'BLT'):
        # op label/imm
        if len(operands) != 1:
            raise ValueError(f"{mnemonic} needs 1 operand: {line}")
        addr = parse_imm(operands[0], labels, line)
        return (op << 12) | addr

    raise ValueError(f"Unrecognised mnemonic: {mnemonic}")


def tokenize_line(raw_line: str):
    """Strip comments, return (label_or_None, mnemonic_or_None, operands_list)."""
    # Remove comment
    line = raw_line.split(';')[0].strip()
    if not line:
        return None, None, []

    # Check for label at start: word followed by colon
    label = None
    label_match = re.match(r'^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)', line)
    if label_match:
        label = label_match.group(1).upper()
        line  = label_match.group(2).strip()

    if not line:
        return label, None, []

    # Split into tokens
    parts = line.split(None, 1)  # split on first whitespace
    mnemonic = parts[0].upper()
    operands = []
    if len(parts) > 1:
        # Split operands by comma, strip whitespace
        operands = [o.strip() for o in parts[1].split(',')]

    return label, mnemonic, operands


def assemble(source: str) -> list:
    """
    Two-pass assembly.
    Pass 1: collect labels → address mapping
    Pass 2: encode instructions
    Returns list of 16-bit integers (one per instruction)
    """
    lines = source.splitlines()

    # --- Pass 1: Label collection ---
    labels = {}
    addr   = 0
    for raw_line in lines:
        label, mnemonic, _ = tokenize_line(raw_line)
        if label:
            if label in labels:
                raise ValueError(f"Duplicate label: {label}")
            labels[label] = addr
        if mnemonic:  # only count lines that produce instructions
            addr += 1

    if addr > 64:
        raise ValueError(f"Program too long: {addr} instructions, max 64")

    # --- Pass 2: Encode ---
    instructions = []
    addr = 0
    for raw_line in lines:
        _, mnemonic, operands = tokenize_line(raw_line)
        if mnemonic is None:
            continue
        if mnemonic not in OPCODES:
            raise ValueError(f"Unknown mnemonic '{mnemonic}' at: {raw_line.strip()}")
        encoded = encode(mnemonic, operands, labels, raw_line.strip())
        instructions.append(encoded)
        addr += 1

    return instructions


def main():
    if len(sys.argv) != 3:
        print("Usage: python assemble.py <input.asm> <output.mem>")
        print("Example: python assemble.py programs/countdown.asm programs/countdown.mem")
        sys.exit(1)

    input_path  = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    if not input_path.exists():
        print(f"Error: input file not found: {input_path}")
        sys.exit(1)

    source = input_path.read_text(encoding='utf-8')

    try:
        instructions = assemble(source)
    except ValueError as e:
        print(f"Assembly error: {e}")
        sys.exit(1)

    # Write output: one hex word per line, with inline comment showing address
    lines_out = []
    lines_out.append(f"// Assembled from: {input_path.name}")
    lines_out.append(f"// {len(instructions)} instruction(s)")
    for i, instr in enumerate(instructions):
        lines_out.append(f"{instr:04X}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text('\n'.join(lines_out) + '\n', encoding='utf-8')

    print(f"Assembled {len(instructions)} instruction(s) → {output_path}")

    # Also print a disassembly for verification
    print(f"\nDisassembly:")
    for i, instr in enumerate(instructions):
        print(f"  [{i:02d}]  0x{instr:04X}  ({instr:016b})")


if __name__ == '__main__':
    main()
