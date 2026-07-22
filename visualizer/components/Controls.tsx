'use client';

import { Program, PROGRAMS } from '@/lib/cpuModel';

interface Props {
  program: Program;
  onSelectProgram: (p: Program) => void;
  onStep: () => void;
  onPlayPause: () => void;
  onReset: () => void;
  isPlaying: boolean;
  isHalted: boolean;
  speed: number;
  onSpeedChange: (s: number) => void;
  cycle: number;
}

export default function Controls({
  program, onSelectProgram,
  onStep, onPlayPause, onReset,
  isPlaying, isHalted,
  speed, onSpeedChange,
  cycle,
}: Props) {
  return (
    <div className="flex flex-wrap items-center gap-3 bg-slate-900 border border-slate-700 rounded-lg px-4 py-3">
      {/* Program selector */}
      <div className="flex items-center gap-2">
        <span className="text-xs text-slate-500 font-mono uppercase">Program</span>
        <div className="flex gap-1">
          {PROGRAMS.map((p) => (
            <button
              key={p.name}
              onClick={() => onSelectProgram(p)}
              className={`px-2.5 py-1 rounded text-xs font-mono transition-colors ${
                p.name === program.name
                  ? 'bg-sky-700 text-sky-100'
                  : 'bg-slate-800 text-slate-400 hover:bg-slate-700 hover:text-slate-200'
              }`}
            >
              {p.name}
            </button>
          ))}
        </div>
      </div>

      <div className="h-5 w-px bg-slate-700" />

      {/* Playback controls */}
      <div className="flex items-center gap-1.5">
        <button
          onClick={onReset}
          className="px-2.5 py-1 rounded text-xs font-mono bg-slate-800 text-slate-400 hover:bg-slate-700 hover:text-slate-200 transition-colors"
        >
          ↺ Reset
        </button>
        <button
          onClick={onStep}
          disabled={isHalted || isPlaying}
          className="px-2.5 py-1 rounded text-xs font-mono bg-slate-800 text-slate-300 hover:bg-slate-700 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
        >
          Step ›
        </button>
        <button
          onClick={onPlayPause}
          disabled={isHalted}
          className={`px-3 py-1 rounded text-xs font-mono transition-colors disabled:opacity-30 disabled:cursor-not-allowed ${
            isPlaying
              ? 'bg-amber-800 text-amber-200 hover:bg-amber-700'
              : 'bg-sky-800 text-sky-200 hover:bg-sky-700'
          }`}
        >
          {isPlaying ? '⏸ Pause' : '▶ Play'}
        </button>
      </div>

      <div className="h-5 w-px bg-slate-700" />

      {/* Speed */}
      <div className="flex items-center gap-2">
        <span className="text-xs text-slate-500 font-mono">Speed</span>
        <input
          type="range" min={100} max={2000} step={100}
          value={2100 - speed}
          onChange={(e) => onSpeedChange(2100 - Number(e.target.value))}
          className="w-20 accent-sky-500"
        />
        <span className="text-xs text-slate-400 font-mono w-14">
          {speed < 400 ? 'Fast' : speed < 900 ? 'Medium' : 'Slow'}
        </span>
      </div>

      <div className="ml-auto flex items-center gap-3">
        {isHalted && (
          <span className="text-xs font-mono text-amber-400 animate-pulse">HALTED</span>
        )}
        <span className="text-xs font-mono text-slate-600">
          Cycle <span className="text-slate-400">{cycle}</span>
        </span>
      </div>
    </div>
  );
}
