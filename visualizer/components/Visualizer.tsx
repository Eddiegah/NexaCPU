'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { NexaCPU, CPUState, Program, PROGRAMS } from '@/lib/cpuModel';
import DatapathDiagram from './DatapathDiagram';
import RegisterPanel from './RegisterPanel';
import MemoryPanel from './MemoryPanel';
import InstructionPanel from './InstructionPanel';
import Controls from './Controls';

export default function Visualizer() {
  const [program, setProgram] = useState<Program>(PROGRAMS[0]);
  const [history, setHistory] = useState<CPUState[]>([]);
  const [currentIdx, setCurrentIdx] = useState(-1);
  const [isPlaying, setIsPlaying] = useState(false);
  const [speed, setSpeed] = useState(900); // ms between steps
  const [animating, setAnimating] = useState(false);
  const [showTour, setShowTour] = useState(true);
  const [tourStep, setTourStep] = useState(0);

  const cpuRef = useRef<NexaCPU>(new NexaCPU(PROGRAMS[0]));
  const playTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const currentState = currentIdx >= 0 ? history[currentIdx] : null;
  const isHalted = currentState?.halt ?? false;

  // Reset when program changes
  const resetCPU = useCallback((p: Program) => {
    if (playTimerRef.current) clearTimeout(playTimerRef.current);
    cpuRef.current = new NexaCPU(p);
    setHistory([]);
    setCurrentIdx(-1);
    setIsPlaying(false);
    setAnimating(false);
  }, []);

  const handleSelectProgram = useCallback((p: Program) => {
    setProgram(p);
    resetCPU(p);
  }, [resetCPU]);

  const handleReset = useCallback(() => {
    resetCPU(program);
  }, [program, resetCPU]);

  const executeStep = useCallback(() => {
    if (cpuRef.current.isHalted) return;
    const state = cpuRef.current.step();
    setHistory((h) => [...h.slice(0, currentIdx + 1), state]);
    setCurrentIdx((i) => i + 1);
    setAnimating(true);
    setTimeout(() => setAnimating(false), speed * 0.8);
  }, [currentIdx, speed]);

  // Auto-play
  useEffect(() => {
    if (!isPlaying) return;
    if (isHalted || cpuRef.current.isHalted) {
      setIsPlaying(false);
      return;
    }
    playTimerRef.current = setTimeout(() => {
      executeStep();
    }, speed);
    return () => { if (playTimerRef.current) clearTimeout(playTimerRef.current); };
  }, [isPlaying, isHalted, executeStep, speed, currentIdx]);

  const handlePlayPause = () => {
    if (isHalted) return;
    setIsPlaying((p) => !p);
  };

  const handleStep = () => {
    if (isPlaying) setIsPlaying(false);
    executeStep();
  };

  // Tour steps
  const tourSteps = [
    {
      title: 'Welcome to NexaCPU',
      body: 'This is a real CPU — designed from scratch in Verilog hardware description language, verified with 124 automated tests, and now visualized here instruction by instruction.',
    },
    {
      title: 'The Datapath',
      body: 'The diagram shows the actual components: Program Counter (PC), Instruction Memory, Control Unit, Register File, ALU, Flags Register, and Data Memory — connected by the exact same signal paths as the hardware.',
    },
    {
      title: 'Data Flow Animation',
      body: 'When you run a program, glowing signals travel along the active paths each cycle — showing you where data is flowing: from registers into the ALU, from the ALU back to registers, from memory, and so on.',
    },
    {
      title: 'Step or Play',
      body: 'Use "Step" to advance one instruction at a time and read the description panel. Use "Play" for automatic execution. Adjust speed with the slider. Three programs are ready to run.',
    },
  ];

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col">
      {/* ── Header ── */}
      <header className="border-b border-slate-800 px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-2 h-2 rounded-full bg-sky-400 animate-pulse" />
          <span className="font-mono text-sky-400 font-bold tracking-tight text-lg">NexaCPU</span>
          <span className="text-slate-600 font-mono text-sm">/ visualizer</span>
        </div>
        <div className="flex items-center gap-4 text-xs font-mono text-slate-500">
          <span>16-bit RISC · 8 registers · Harvard architecture</span>
          <a
            href="https://github.com/Eddiegah/NexaCPU"
            className="text-sky-600 hover:text-sky-400 transition-colors"
            target="_blank" rel="noopener noreferrer"
          >
            GitHub ↗
          </a>
        </div>
      </header>

      {/* ── Tour overlay ── */}
      <AnimatePresence>
        {showTour && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-6"
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              className="bg-slate-900 border border-slate-700 rounded-2xl p-8 max-w-lg w-full shadow-2xl"
            >
              <div className="flex items-center gap-2 mb-1">
                <div className="w-1.5 h-1.5 rounded-full bg-sky-400" />
                <span className="text-xs font-mono text-sky-500 uppercase tracking-wider">
                  {tourStep + 1} / {tourSteps.length}
                </span>
              </div>
              <h2 className="text-xl font-bold text-white mb-3 font-mono">
                {tourSteps[tourStep].title}
              </h2>
              <p className="text-slate-300 leading-relaxed mb-6">
                {tourSteps[tourStep].body}
              </p>
              <div className="flex items-center justify-between">
                <div className="flex gap-1.5">
                  {tourSteps.map((_, i) => (
                    <div key={i} className={`w-1.5 h-1.5 rounded-full ${i === tourStep ? 'bg-sky-400' : 'bg-slate-700'}`} />
                  ))}
                </div>
                <div className="flex gap-2">
                  <button
                    onClick={() => setShowTour(false)}
                    className="px-3 py-1.5 rounded text-sm text-slate-500 hover:text-slate-300 transition-colors"
                  >
                    Skip
                  </button>
                  <button
                    onClick={() => {
                      if (tourStep < tourSteps.length - 1) setTourStep((s) => s + 1);
                      else setShowTour(false);
                    }}
                    className="px-4 py-1.5 bg-sky-700 hover:bg-sky-600 text-white rounded text-sm font-mono transition-colors"
                  >
                    {tourStep < tourSteps.length - 1 ? 'Next →' : 'Start Exploring'}
                  </button>
                </div>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── Main content ── */}
      <main className="flex-1 flex flex-col gap-3 p-4 max-w-screen-2xl mx-auto w-full">

        {/* Controls bar */}
        <Controls
          program={program}
          onSelectProgram={handleSelectProgram}
          onStep={handleStep}
          onPlayPause={handlePlayPause}
          onReset={handleReset}
          isPlaying={isPlaying}
          isHalted={isHalted}
          speed={speed}
          onSpeedChange={setSpeed}
          cycle={currentState?.cycle ?? 0}
        />

        {/* Program description */}
        <div className="bg-slate-900/50 border border-slate-800 rounded-lg px-4 py-2">
          <p className="text-sm text-slate-400 font-mono">
            <span className="text-sky-500">{program.name}:</span>{' '}
            {program.description}
          </p>
        </div>

        {/* Three-column layout */}
        <div className="flex gap-3 flex-1 min-h-0">

          {/* Left: Instruction + register panels */}
          <div className="flex flex-col gap-3 w-72 shrink-0">
            <InstructionPanel state={currentState} program={program} />
            <RegisterPanel state={currentState} />
          </div>

          {/* Center: Datapath diagram */}
          <div className="flex-1 bg-slate-900 border border-slate-700 rounded-lg overflow-hidden min-h-[500px] relative">
            <div className="absolute inset-0 p-4">
              <DatapathDiagram state={currentState} animating={animating} />
            </div>
            {/* Cycle watermark */}
            {currentState && (
              <div className="absolute bottom-3 right-4 text-slate-800 font-mono text-xs">
                cycle {currentState.cycle}
              </div>
            )}
            {/* Empty state */}
            {!currentState && (
              <div className="absolute inset-0 flex items-center justify-center">
                <div className="text-center space-y-2">
                  <div className="text-4xl">⚡</div>
                  <p className="text-slate-600 font-mono text-sm">Press Step or Play to run the CPU</p>
                </div>
              </div>
            )}
          </div>

          {/* Right: Memory panel */}
          <div className="w-52 shrink-0">
            <MemoryPanel state={currentState} />
          </div>

        </div>
      </main>

      <footer className="border-t border-slate-800 px-6 py-3 text-xs font-mono text-slate-700 flex justify-between">
        <span>Verilog source of truth in <code>hardware/</code> — this is a verified behavioral mirror</span>
        <a href="https://github.com/Eddiegah/NexaCPU" target="_blank" rel="noopener noreferrer"
           className="text-slate-600 hover:text-slate-400 transition-colors">
          github.com/Eddiegah/NexaCPU ↗
        </a>
      </footer>
    </div>
  );
}
