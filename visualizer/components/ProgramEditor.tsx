'use client';

import { useState, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { assemble, ISA_REFERENCE, AssemblyError } from '@/lib/assembler';
import { Program } from '@/lib/cpuModel';

interface Props {
  open: boolean;
  onClose: () => void;
  onLoad: (program: Program) => void;
}

const STARTER = `; Write your NexaCPU program here.
; Registers: R0 (always 0), R1–R7
; Immediates: 0–63
; Labels: word followed by colon

    LOADI R1, 10        ; R1 = 10
    LOADI R2, 3         ; R2 = 3
    ADD   R3, R1, R2    ; R3 = R1 + R2
    HALT
`;

export default function ProgramEditor({ open, onClose, onLoad }: Props) {
  const [source, setSource] = useState(STARTER);
  const [errors, setErrors] = useState<AssemblyError[]>([]);
  const [assembled, setAssembled] = useState<number[] | null>(null);
  const [progName, setProgName] = useState('My Program');
  const [showRef, setShowRef] = useState(false);

  const handleAssemble = useCallback(() => {
    const result = assemble(source);
    if (result.ok) {
      setErrors([]);
      setAssembled(result.instructions);
    } else {
      setErrors(result.errors);
      setAssembled(null);
    }
  }, [source]);

  const handleLoad = useCallback(() => {
    const result = assemble(source);
    if (!result.ok) { setErrors(result.errors); return; }

    const program: Program = {
      name: progName.trim() || 'Custom',
      description: `Custom program — ${result.instructions.length} instructions`,
      source,
      instructions: result.instructions,
    };
    onLoad(program);
    onClose();
  }, [source, progName, onLoad, onClose]);

  // Highlight error lines in the textarea (we show a gutter overlay)
  const errorLines = new Set(errors.map(e => e.line));
  const sourceLines = source.split('\n');

  return (
    <AnimatePresence>
      {open && (
        <>
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 bg-slate-950/70 backdrop-blur-sm z-40"
          />

          {/* Panel — slides in from the right */}
          <motion.div
            initial={{ x: '100%' }}
            animate={{ x: 0 }}
            exit={{ x: '100%' }}
            transition={{ type: 'spring', stiffness: 300, damping: 30 }}
            className="fixed right-0 top-0 h-full w-full max-w-2xl bg-slate-900 border-l border-slate-700 z-50 flex flex-col shadow-2xl"
          >
            {/* Header */}
            <div className="flex items-center justify-between px-5 py-4 border-b border-slate-700 shrink-0">
              <div className="flex items-center gap-3">
                <span className="text-sky-400 font-mono font-bold">✎ Program Editor</span>
                <span className="text-slate-600 text-xs font-mono">NexaCPU assembler</span>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setShowRef(r => !r)}
                  className={`px-2.5 py-1 rounded text-xs font-mono transition-colors ${
                    showRef ? 'bg-sky-900 text-sky-300' : 'bg-slate-800 text-slate-400 hover:bg-slate-700'
                  }`}
                >
                  ISA ref
                </button>
                <button
                  onClick={onClose}
                  className="px-2.5 py-1 rounded text-xs font-mono bg-slate-800 text-slate-400 hover:bg-slate-700 transition-colors"
                >
                  ✕ Close
                </button>
              </div>
            </div>

            {/* Body */}
            <div className="flex flex-1 min-h-0 overflow-hidden">

              {/* Editor column */}
              <div className="flex flex-col flex-1 min-w-0 overflow-hidden">

                {/* Program name input */}
                <div className="px-5 pt-3 pb-2 border-b border-slate-800 shrink-0">
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-mono text-slate-500 shrink-0">Name:</span>
                    <input
                      value={progName}
                      onChange={e => setProgName(e.target.value)}
                      className="flex-1 bg-slate-800 border border-slate-700 rounded px-2 py-1 text-xs font-mono text-slate-200 focus:outline-none focus:border-sky-600"
                      maxLength={30}
                    />
                  </div>
                </div>

                {/* Editor with line numbers */}
                <div className="flex flex-1 min-h-0 overflow-hidden font-mono text-xs">
                  {/* Line number gutter */}
                  <div
                    className="select-none bg-slate-950/50 border-r border-slate-800 text-right px-2 py-3 text-slate-700 leading-[1.6rem] shrink-0 overflow-hidden"
                    style={{ minWidth: '2.5rem' }}
                  >
                    {sourceLines.map((_, i) => (
                      <div
                        key={i}
                        className={`${errorLines.has(i + 1) ? 'text-red-500' : ''}`}
                      >
                        {i + 1}
                      </div>
                    ))}
                  </div>

                  {/* Textarea */}
                  <textarea
                    value={source}
                    onChange={e => { setSource(e.target.value); setAssembled(null); setErrors([]); }}
                    spellCheck={false}
                    className="flex-1 bg-transparent resize-none px-3 py-3 text-slate-200 leading-[1.6rem] focus:outline-none caret-sky-400 overflow-y-auto"
                    style={{ fontFamily: 'inherit' }}
                  />
                </div>

                {/* Error panel */}
                {errors.length > 0 && (
                  <div className="border-t border-red-900/50 bg-red-950/30 px-4 py-2 max-h-32 overflow-y-auto shrink-0">
                    {errors.map((e, i) => (
                      <div key={i} className="flex gap-2 text-xs font-mono text-red-400 py-0.5">
                        <span className="text-red-600 shrink-0">Line {e.line}:</span>
                        <span>{e.message}</span>
                      </div>
                    ))}
                  </div>
                )}

                {/* Assembled output preview */}
                {assembled && (
                  <div className="border-t border-emerald-900/40 bg-emerald-950/20 px-4 py-2 shrink-0">
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-xs font-mono text-emerald-400">
                        ✓ {assembled.length} instruction{assembled.length !== 1 ? 's' : ''} assembled
                      </span>
                    </div>
                    <div className="flex flex-wrap gap-1.5">
                      {assembled.map((w, i) => (
                        <span key={i} className="text-[10px] font-mono text-emerald-600 bg-emerald-950/50 px-1 rounded">
                          [{i}] {w.toString(16).toUpperCase().padStart(4, '0')}
                        </span>
                      ))}
                    </div>
                  </div>
                )}

                {/* Action buttons */}
                <div className="px-5 py-3 border-t border-slate-800 flex gap-2 shrink-0">
                  <button
                    onClick={handleAssemble}
                    className="px-3 py-1.5 bg-slate-700 hover:bg-slate-600 text-slate-200 rounded text-xs font-mono transition-colors"
                  >
                    Assemble
                  </button>
                  <button
                    onClick={handleLoad}
                    className="px-4 py-1.5 bg-sky-700 hover:bg-sky-600 text-white rounded text-xs font-mono transition-colors font-bold"
                  >
                    ▶ Load &amp; Run
                  </button>
                  <button
                    onClick={() => { setSource(STARTER); setErrors([]); setAssembled(null); }}
                    className="ml-auto px-2.5 py-1.5 text-slate-600 hover:text-slate-400 rounded text-xs font-mono transition-colors"
                  >
                    Reset to example
                  </button>
                </div>
              </div>

              {/* ISA reference sidebar */}
              <AnimatePresence>
                {showRef && (
                  <motion.div
                    initial={{ width: 0, opacity: 0 }}
                    animate={{ width: 220, opacity: 1 }}
                    exit={{ width: 0, opacity: 0 }}
                    transition={{ duration: 0.2 }}
                    className="border-l border-slate-800 bg-slate-950/50 overflow-hidden shrink-0"
                  >
                    <div className="p-3 w-[220px]">
                      <p className="text-[10px] font-mono text-slate-500 uppercase tracking-wider mb-2">
                        Instruction Set
                      </p>
                      <div className="space-y-2">
                        {ISA_REFERENCE.map(row => (
                          <div key={row.mnemonic}>
                            <div className="text-[11px] font-mono text-sky-400">{row.syntax}</div>
                            <div className="text-[10px] font-mono text-slate-600 ml-1">{row.description}</div>
                          </div>
                        ))}
                      </div>
                      <div className="mt-4 border-t border-slate-800 pt-3 space-y-1 text-[10px] font-mono text-slate-600">
                        <p className="text-slate-500 font-bold">Notes</p>
                        <p>R0 is always 0 (writes ignored)</p>
                        <p>Immediates: 0–63 only</p>
                        <p>Addresses: 0–63</p>
                        <p>BEQ/BNE/BLT need a prior CMP</p>
                        <p>; starts a comment</p>
                        <p>label: defines a jump target</p>
                      </div>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
