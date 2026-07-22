#!/usr/bin/env python3
"""Quick decoder — prints human-readable disassembly of a .mem file."""
import sys

MN = {0:'LOADI',1:'LOAD',2:'STORE',3:'MOV',4:'ADD',5:'SUB',
      6:'AND',7:'OR',8:'NOT',9:'CMP',10:'JMP',11:'BEQ',
      12:'BNE',13:'BLT',15:'HALT'}

def decode(w):
    op  = (w >> 12) & 0xF
    rd  = (w >>  9) & 0x7
    rs1 = (w >>  6) & 0x7
    rs2 =  w        & 0x7
    imm =  w        & 0x3F
    mn  = MN.get(op, '???')
    if mn == 'HALT':  return f'HALT'
    if mn == 'LOADI': return f'LOADI R{rd}, {imm}'
    if mn in ('LOAD','MOV','NOT'): return f'{mn} R{rd}, R{rs1}'
    if mn == 'STORE': return f'STORE R{rs1}, R{rs2}'
    if mn in ('ADD','SUB','AND','OR'): return f'{mn} R{rd}, R{rs1}, R{rs2}'
    if mn == 'CMP':   return f'CMP R{rs1}, R{rs2}'
    if mn in ('JMP','BEQ','BNE','BLT'): return f'{mn} {imm}'
    return f'??? 0x{w:04X}'

path = sys.argv[1]
words = []
for line in open(path):
    line = line.split('//')[0].strip()
    if line: words.append(int(line, 16))

for i, w in enumerate(words):
    print(f'[{i:02d}]  0x{w:04X}   {decode(w)}')
