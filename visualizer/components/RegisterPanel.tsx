'use client';

import { motion } from 'framer-motion';
import { CPUState } from '@/lib/cpuModel';

interface Props {
  state: CPUState | null;
}

export default function RegisterPanel({ state }: Props) {
  if (!state) {
    return (
      <div className="bg-slate-900 border border-slate-700 rounded-lg p-4">
        <h3 className="text-xs font-mono text-slate-400 uppercase tracking-wider mb-3">Registers</h3>
        <div className="space-y-1">
          {Array.from({ length: 8 }, (_, i) => (
            <div key={i} className="flex justify-between items-center py-1 px-2 rounded">
              <span className="text-slate-500 font-mono text-xs">R{i}</span>
              <span className="text-slate-600 font-mono text-xs">0x0000</span>
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="bg-slate-900 border border-slate-700 rounded-lg p-4">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-xs font-mono text-slate-400 uppercase tracking-wider">Registers</h3>
        <div className="flex gap-2 text-xs font-mono">
          <span className={`px-1.5 py-0.5 rounded text-[10px] ${state.flagZero ? 'bg-cyan-900 text-cyan-300' : 'bg-slate-800 text-slate-600'}`}>Z</span>
          <span className={`px-1.5 py-0.5 rounded text-[10px] ${state.flagNeg  ? 'bg-pink-900 text-pink-300' : 'bg-slate-800 text-slate-600'}`}>N</span>
          <span className={`px-1.5 py-0.5 rounded text-[10px] ${state.flagCarry? 'bg-amber-900 text-amber-300' : 'bg-slate-800 text-slate-600'}`}>C</span>
        </div>
      </div>

      <div className="space-y-0.5">
        {state.regs.map((val, i) => {
          const isChanged = state.changedRegs.includes(i);
          const isR0 = i === 0;
          const isRs1 = state.rs1 === i && !state.halt;
          const isRs2 = state.rs2 === i && !state.halt && !state.aluSrc;
          const isRd  = state.rd === i  && state.regWrite && !state.halt;

          return (
            <motion.div
              key={i}
              className={`flex justify-between items-center py-1 px-2 rounded transition-colors ${
                isChanged  ? 'bg-blue-900/60 border border-blue-700/50' :
                isRd       ? 'bg-blue-950/40 border border-blue-800/30' :
                isR0       ? 'bg-slate-950/50' :
                'hover:bg-slate-800/30'
              }`}
              animate={isChanged ? { scale: [1, 1.03, 1] } : {}}
              transition={{ duration: 0.3 }}
            >
              <div className="flex items-center gap-1.5">
                <span className={`font-mono text-xs ${isR0 ? 'text-slate-600' : 'text-slate-400'}`}>
                  R{i}
                </span>
                {isRs1 && <span className="text-[9px] text-emerald-400 font-mono">rs1</span>}
                {isRs2 && <span className="text-[9px] text-emerald-500 font-mono">rs2</span>}
                {isRd  && <span className="text-[9px] text-sky-400 font-mono">→ dst</span>}
                {isR0  && <span className="text-[9px] text-slate-600 font-mono">zero</span>}
              </div>
              <div className="flex items-center gap-2">
                <span className={`font-mono text-xs tabular-nums ${
                  isChanged ? 'text-sky-300 font-bold' :
                  isR0      ? 'text-slate-600' :
                  'text-slate-300'
                }`}>
                  {isR0 ? '0' : val}
                </span>
                <span className="font-mono text-[10px] text-slate-600">
                  0x{(isR0 ? 0 : val).toString(16).toUpperCase().padStart(4, '0')}
                </span>
              </div>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}
