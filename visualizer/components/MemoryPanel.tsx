'use client';

import { motion } from 'framer-motion';
import { CPUState } from '@/lib/cpuModel';

interface Props {
  state: CPUState | null;
}

export default function MemoryPanel({ state }: Props) {
  // Only show non-zero memory locations + a few context rows
  const mem = state?.dataMem ?? new Array(64).fill(0);
  const changedMem = state?.changedMem ?? [];

  // Find range to display: always show 0–15, highlight non-zero and changed
  const rowsToShow = Array.from({ length: 16 }, (_, i) => i);

  return (
    <div className="bg-slate-900 border border-slate-700 rounded-lg p-4">
      <h3 className="text-xs font-mono text-slate-400 uppercase tracking-wider mb-3">
        Data Memory
        <span className="ml-2 text-slate-600 normal-case">(addr 0–15)</span>
      </h3>
      <div className="space-y-0.5">
        {rowsToShow.map((addr) => {
          const val = mem[addr];
          const isChanged = changedMem.includes(addr);
          const isAddrReg = state?.memRead || state?.memWrite
            ? (state.aluA & 0x3F) === addr
            : false;
          const nonZero = val !== 0;

          return (
            <motion.div
              key={addr}
              className={`flex justify-between items-center py-0.5 px-2 rounded text-xs font-mono ${
                isChanged  ? 'bg-amber-900/50 border border-amber-700/40' :
                isAddrReg  ? 'bg-slate-700/30 border border-slate-600/30' :
                nonZero    ? 'bg-slate-800/20' :
                ''
              }`}
              animate={isChanged ? { scale: [1, 1.04, 1] } : {}}
              transition={{ duration: 0.3 }}
            >
              <span className={`${isAddrReg ? 'text-amber-400' : 'text-slate-600'}`}>
                [{addr.toString().padStart(2, '0')}]
              </span>
              <span className={`tabular-nums ${
                isChanged ? 'text-amber-300 font-bold' :
                nonZero   ? 'text-slate-300' :
                'text-slate-700'
              }`}>
                {val}
              </span>
              <span className="text-slate-700 text-[10px]">
                {val !== 0 ? `0x${val.toString(16).toUpperCase().padStart(4,'0')}` : '—'}
              </span>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}
