'use client';

import { motion } from 'framer-motion';
import { CPUState, Program } from '@/lib/cpuModel';

interface Props {
  state: CPUState | null;
  program: Program;
}

export default function InstructionPanel({ state, program }: Props) {
  const lines = program.source.split('\n').filter(Boolean);
  // Map source lines to instruction addresses (skip comment/label-only lines)
  const instrLines: { addr: number; line: string }[] = [];
  let addr = 0;
  for (const line of lines) {
    const stripped = line.replace(/;.*$/, '').trim();
    const isLabelOnly = /^[A-Za-z_]\w*:\s*$/.test(stripped);
    const isEmpty = stripped === '';
    if (!isEmpty && !isLabelOnly) {
      instrLines.push({ addr, line: line.trimStart() });
      addr++;
    } else {
      instrLines.push({ addr: -1, line: line.trimStart() }); // label/comment row
    }
  }

  const currentAddr = state?.pc ?? -1;

  return (
    <div className="bg-slate-900 border border-slate-700 rounded-lg p-4 flex flex-col gap-3">
      {/* Current instruction readout */}
      <div>
        <h3 className="text-xs font-mono text-slate-400 uppercase tracking-wider mb-2">
          Current Instruction
        </h3>
        {state ? (
          <motion.div
            key={state.cycle}
            initial={{ opacity: 0, y: -4 }}
            animate={{ opacity: 1, y: 0 }}
            className="bg-slate-800 rounded-lg p-3 space-y-1"
          >
            <div className="flex items-center gap-3">
              <span className="text-sky-400 font-mono text-lg font-bold">{state.opName}</span>
              <span className="text-slate-500 font-mono text-xs">
                0x{state.instr.toString(16).toUpperCase().padStart(4,'0')}
              </span>
              <span className="text-slate-600 font-mono text-[10px]">
                {state.instr.toString(2).padStart(16,'0').replace(/(.{4})/g,'$1 ').trim()}
              </span>
            </div>
            <p className="text-slate-300 text-sm leading-relaxed">{state.description}</p>
            <div className="flex gap-3 text-[10px] font-mono text-slate-500 pt-1 flex-wrap">
              <span>PC: {state.pc}</span>
              <span>rd: R{state.rd}</span>
              <span>rs1: R{state.rs1}</span>
              <span>rs2: R{state.rs2}</span>
              <span>imm6: {state.imm6}</span>
              <span>cycle: {state.cycle}</span>
            </div>
          </motion.div>
        ) : (
          <div className="bg-slate-800/50 rounded-lg p-3 text-slate-600 text-sm font-mono">
            Press Step or Play to begin
          </div>
        )}
      </div>

      {/* Assembly listing */}
      <div>
        <h3 className="text-xs font-mono text-slate-400 uppercase tracking-wider mb-2">
          Program Listing
        </h3>
        <div className="font-mono text-xs space-y-0 max-h-52 overflow-y-auto pr-1">
          {instrLines.map(({ addr: a, line }, i) => {
            const isCurrent = a !== -1 && a === currentAddr;
            const isLabel = a === -1 && line.includes(':');
            const isComment = a === -1 && line.trimStart().startsWith(';');
            return (
              <motion.div
                key={i}
                className={`px-2 py-0.5 rounded flex items-center gap-2 ${
                  isCurrent ? 'bg-sky-950 border-l-2 border-sky-400' :
                  'border-l-2 border-transparent'
                }`}
                animate={isCurrent ? { backgroundColor: ['#082f4900', '#082f4966', '#082f4966'] } : {}}
              >
                {a !== -1 ? (
                  <span className="text-slate-700 w-5 text-right shrink-0">{a}</span>
                ) : (
                  <span className="w-5" />
                )}
                <span className={`${
                  isCurrent ? 'text-sky-200' :
                  isLabel   ? 'text-violet-400' :
                  isComment ? 'text-slate-600' :
                  'text-slate-400'
                }`}>
                  {isCurrent && <span className="text-sky-400 mr-1">▶</span>}
                  {line}
                </span>
              </motion.div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
