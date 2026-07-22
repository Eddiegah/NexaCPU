/**
 * NexaCPU JS Model — Behavioral verification tests
 * Run with: npx ts-node lib/cpuModel.test.ts
 *
 * Verifies that the JS model produces the same final state as the
 * Verilog simulation (Phase 1 hardware/testbenches/cpu_tb.v results).
 */

import { NexaCPU, PROGRAMS } from './cpuModel';

let passed = 0;
let failed = 0;

function expect(label: string, got: number | boolean, expected: number | boolean) {
  if (got === expected) {
    console.log(`  PASS  ${label} = ${got}`);
    passed++;
  } else {
    console.error(`  FAIL  ${label}: got ${got}, expected ${expected}`);
    failed++;
  }
}

// ============================================================================
// Program 1: Arithmetic
// Expected: R1=5, R2=10, R3=12, R4=24, R5=8, R6=3, R7=15
// ============================================================================
console.log('\n=== Program 1: Arithmetic ===');
{
  const cpu = new NexaCPU(PROGRAMS[0]);
  const states = cpu.runAll();
  const last = states[states.length - 1];
  expect('R1', last.regs[1], 5);
  expect('R2', last.regs[2], 10);
  expect('R3', last.regs[3], 12);
  expect('R4', last.regs[4], 24);
  expect('R5', last.regs[5], 8);
  expect('R6', last.regs[6], 3);
  expect('R7', last.regs[7], 15);
  expect('halted', last.halt, true);
  console.log(`  Completed in ${states.length} cycles`);
}

// ============================================================================
// Program 2: Countdown Loop
// Expected: R1=0, R2=1, R3=5, R4=1
// ============================================================================
console.log('\n=== Program 2: Countdown Loop ===');
{
  const cpu = new NexaCPU(PROGRAMS[1]);
  const states = cpu.runAll();
  const last = states[states.length - 1];
  expect('R1 (=0)', last.regs[1], 0);
  expect('R2 (=1)', last.regs[2], 1);
  expect('R3 (=5 iters)', last.regs[3], 5);
  expect('R4 (=1)', last.regs[4], 1);
  expect('halted', last.halt, true);
  console.log(`  Completed in ${states.length} cycles`);
}

// ============================================================================
// Program 3: Fibonacci
// Expected memory: mem[2]=1, mem[3]=2, mem[4]=3, mem[5]=5, mem[6]=8, mem[7]=13
// ============================================================================
console.log('\n=== Program 3: Fibonacci ===');
{
  const cpu = new NexaCPU(PROGRAMS[2]);
  const states = cpu.runAll();
  const last = states[states.length - 1];
  expect('mem[2]', last.dataMem[2], 1);
  expect('mem[3]', last.dataMem[3], 2);
  expect('mem[4]', last.dataMem[4], 3);
  expect('mem[5]', last.dataMem[5], 5);
  expect('mem[6]', last.dataMem[6], 8);
  expect('mem[7]', last.dataMem[7], 13);
  expect('halted', last.halt, true);
  console.log(`  Completed in ${states.length} cycles`);
}

// ============================================================================
// Unit: R0 hardwired to zero
// ============================================================================
console.log('\n=== Unit: R0 hardwired to zero ===');
{
  // LOADI R0, 42 should be a no-op
  const cpu = new NexaCPU({
    name: 'test',
    description: '',
    source: '',
    instructions: [
      0x0000 | (0 << 9) | 42,  // LOADI R0, 42
      0xF000,                   // HALT
    ],
  });
  const states = cpu.runAll();
  const last = states[states.length - 1];
  expect('R0 after write attempt', last.regs[0], 0);
}

// ============================================================================
// Unit: Registered flags (BEQ reads flags from prior CMP)
// ============================================================================
console.log('\n=== Unit: Registered flags ===');
{
  // LOADI R1, 5
  // LOADI R2, 5
  // CMP R1, R2   ; should set Z=1
  // BEQ 5        ; should branch to addr 5
  // LOADI R3, 99 ; should be skipped
  // HALT         ; addr 5
  const cpu = new NexaCPU({
    name: 'flag-test',
    description: '',
    source: '',
    instructions: [
      0x0000 | (1 << 9) | 5,   // LOADI R1, 5
      0x0000 | (2 << 9) | 5,   // LOADI R2, 5
      0x9000 | (1 << 6) | 2,   // CMP R1, R2
      0xB000 | 5,               // BEQ 5
      0x0000 | (3 << 9) | 99,  // LOADI R3, 99  (should be skipped)
      0xF000,                   // HALT
    ],
  });
  const states = cpu.runAll();
  const last = states[states.length - 1];
  expect('R3 not written (branch taken)', last.regs[3], 0);
  expect('halted', last.halt, true);
}

// ============================================================================
// Final report
// ============================================================================
console.log(`\n${'='.repeat(44)}`);
console.log(`  Results: ${passed} passed, ${failed} failed (of ${passed + failed})`);
if (failed === 0) console.log('  ALL TESTS PASSED — JS model verified. ✓');
else console.error('  SOME TESTS FAILED');
console.log('='.repeat(44));

process.exit(failed > 0 ? 1 : 0);
