'use client';

import { motion } from 'framer-motion';
import { useEffect, useState } from 'react';
import { CPUState, ActivePath } from '@/lib/cpuModel';

interface Props {
  state: CPUState | null;
  animating: boolean;
}

// ---------------------------------------------------------------------------
// Layout — every block's bounding box
// ---------------------------------------------------------------------------
const W = 900, H = 560;

const BLOCKS = {
  pc:    { x: 30,  y: 220, w: 80,  h: 50  },
  imem:  { x: 160, y: 130, w: 110, h: 70  },
  cu:    { x: 160, y: 255, w: 110, h: 80  },
  regs:  { x: 355, y: 130, w: 115, h: 125 },
  alu:   { x: 555, y: 190, w: 115, h: 80  },
  flags: { x: 555, y: 355, w: 115, h: 55  },
  dmem:  { x: 730, y: 130, w: 115, h: 105 },
} as const;

type BK = keyof typeof BLOCKS;
const cx  = (b: BK) => BLOCKS[b].x + BLOCKS[b].w / 2;
const cy  = (b: BK) => BLOCKS[b].y + BLOCKS[b].h / 2;
const rx  = (b: BK) => BLOCKS[b].x + BLOCKS[b].w;
const lx  = (b: BK) => BLOCKS[b].x;
const ty  = (b: BK) => BLOCKS[b].y;
const by  = (b: BK) => BLOCKS[b].y + BLOCKS[b].h;

// ---------------------------------------------------------------------------
// Path data for every signal route
// ---------------------------------------------------------------------------
const PATHS: Record<ActivePath, string> = {
  'pc-to-imem':       `M ${rx('pc')} ${cy('pc')} L ${lx('imem')} ${cy('imem')}`,
  'imem-to-cu':       `M ${cx('imem')} ${by('imem')} L ${cx('cu')} ${ty('cu')}`,
  'cu-to-regs':       `M ${rx('cu')} ${cy('cu')} L ${lx('regs')} ${cy('regs') + 20}`,
  'regs-to-alu':      `M ${rx('regs')} ${cy('regs') - 15} L ${lx('alu')} ${cy('alu')}`,
  'imm-to-alu':       `M ${cx('cu')} ${by('cu') + 8} C ${cx('cu')} ${cy('alu') + 60}, ${lx('alu') - 25} ${cy('alu') + 30}, ${lx('alu')} ${cy('alu') + 20}`,
  'alu-to-regs':      `M ${lx('alu')} ${cy('alu') - 15} C ${cx('regs') + 15} ${ty('regs') - 50}, ${cx('regs') + 15} ${ty('regs') - 40}, ${rx('regs')} ${cy('regs') - 25}`,
  'alu-to-flags':     `M ${cx('alu')} ${by('alu')} L ${cx('flags')} ${ty('flags')}`,
  'regs-to-dmem':     `M ${rx('regs')} ${cy('regs') + 20} C ${cx('alu') + 20} ${cy('regs') + 20}, ${lx('dmem') - 20} ${cy('dmem') + 20}, ${lx('dmem')} ${cy('dmem') + 20}`,
  'dmem-to-regs':     `M ${lx('dmem')} ${cy('dmem') - 20} C ${cx('alu') - 20} ${cy('dmem') - 20}, ${rx('regs') + 20} ${cy('regs') - 25}, ${rx('regs')} ${cy('regs') - 30}`,
  'alu-to-dmem-addr': `M ${rx('alu')} ${cy('alu')} L ${lx('dmem')} ${cy('dmem') - 10}`,
  'branch-taken':     `M ${cx('flags')} ${by('flags') + 8} C ${cx('flags')} ${H - 28}, 55 ${H - 28}, ${cx('pc')} ${by('pc')}`,
  'pc-increment':     `M ${lx('pc')} ${cy('pc')} C -18 ${cy('pc')}, -18 ${ty('pc') - 18}, ${cx('pc')} ${ty('pc')}`,
};

const COLORS: Record<ActivePath, string> = {
  'pc-to-imem':        '#38bdf8',
  'imem-to-cu':        '#818cf8',
  'cu-to-regs':        '#a78bfa',
  'regs-to-alu':       '#34d399',
  'imm-to-alu':        '#fb923c',
  'alu-to-regs':       '#4ade80',
  'alu-to-flags':      '#f472b6',
  'regs-to-dmem':      '#fbbf24',
  'dmem-to-regs':      '#22d3ee',
  'alu-to-dmem-addr':  '#f87171',
  'branch-taken':      '#c084fc',
  'pc-increment':      '#94a3b8',
};

// Animation duration in milliseconds
const ANIM_MS = 650;

// ---------------------------------------------------------------------------
// Signal packet — uses native SVG <animateMotion> for cross-browser support.
// This approach works in every browser without CSS offsetPath.
// A new element is mounted per cycle (key includes cycle number) so the
// animation always replays from the start for each new instruction.
// ---------------------------------------------------------------------------
function Packet({ pathD, color, cycle }: { pathD: string; color: string; cycle: number }) {
  return (
    <g key={`${pathD}-${cycle}`}>
      {/* Glow halo */}
      <circle r={8} fill={color} opacity={0.25}>
        <animateMotion
          dur={`${ANIM_MS}ms`}
          fill="freeze"
          path={pathD}
        />
        <animate attributeName="opacity" values="0.25;0.25;0" keyTimes="0;0.6;1"
          dur={`${ANIM_MS}ms`} fill="freeze" />
      </circle>
      {/* Core dot */}
      <circle r={5} fill={color} style={{ filter: `drop-shadow(0 0 4px ${color})` }}>
        <animateMotion
          dur={`${ANIM_MS}ms`}
          fill="freeze"
          path={pathD}
        />
        <animate attributeName="opacity" values="1;1;0" keyTimes="0;0.65;1"
          dur={`${ANIM_MS}ms`} fill="freeze" />
      </circle>
    </g>
  );
}

// ---------------------------------------------------------------------------
// Block box
// ---------------------------------------------------------------------------
function Block({ b, label, sublabel, active }: {
  b: BK; label: string; sublabel?: string; active?: boolean;
}) {
  const { x, y, w, h } = BLOCKS[b];
  return (
    <g>
      <motion.rect
        x={x} y={y} width={w} height={h} rx={7}
        fill={active ? '#0c2340' : '#0f172a'}
        stroke={active ? '#38bdf8' : '#1e293b'}
        strokeWidth={active ? 2 : 1}
        animate={{
          stroke: active ? '#38bdf8' : '#1e293b',
          fill:   active ? '#0c2340' : '#0f172a',
        }}
        transition={{ duration: 0.25 }}
      />
      <text
        x={x + w / 2} y={sublabel ? y + h / 2 - 9 : y + h / 2}
        textAnchor="middle" dominantBaseline="middle"
        fill={active ? '#e2e8f0' : '#94a3b8'}
        fontSize={11} fontFamily="monospace" fontWeight="700"
        style={{ pointerEvents: 'none', userSelect: 'none' }}
      >
        {label}
      </text>
      {sublabel && (
        <text
          x={x + w / 2} y={y + h / 2 + 9}
          textAnchor="middle" dominantBaseline="middle"
          fill={active ? '#38bdf8' : '#475569'}
          fontSize={10} fontFamily="monospace"
          style={{ pointerEvents: 'none', userSelect: 'none' }}
        >
          {sublabel}
        </text>
      )}
    </g>
  );
}

// ---------------------------------------------------------------------------
// Main diagram
// ---------------------------------------------------------------------------
export default function DatapathDiagram({ state, animating }: Props) {
  const active = state?.activePaths ?? [];

  // Track a render key so packets remount each cycle
  const [packetKey, setPacketKey] = useState(0);
  useEffect(() => {
    if (animating) setPacketKey(k => k + 1);
  }, [animating, state?.cycle]);

  const isActive = (p: ActivePath) => animating && active.includes(p);

  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="w-full h-full" style={{ background: 'transparent' }}>
      <defs>
        <marker id="arr-dim" markerWidth="5" markerHeight="5" refX="4" refY="2.5" orient="auto">
          <path d="M0,0 L5,2.5 L0,5 Z" fill="#1e293b" />
        </marker>
        <marker id="arr-bright" markerWidth="5" markerHeight="5" refX="4" refY="2.5" orient="auto">
          <path d="M0,0 L5,2.5 L0,5 Z" fill="#38bdf8" />
        </marker>
      </defs>

      {/* ── Static wiring ── */}
      {(Object.entries(PATHS) as [ActivePath, string][]).map(([id, d]) => {
        const on = isActive(id);
        const col = COLORS[id];
        return (
          <motion.path
            key={id} d={d} fill="none"
            stroke={on ? col : '#1e293b'}
            strokeWidth={on ? 2.5 : 1.5}
            strokeDasharray={on ? 'none' : '4 3'}
            markerEnd={on ? 'url(#arr-bright)' : 'url(#arr-dim)'}
            animate={{ stroke: on ? col : '#1e293b', strokeWidth: on ? 2.5 : 1.5 }}
            transition={{ duration: 0.25 }}
          />
        );
      })}

      {/* ── Signal packets (SVG animateMotion — cross-browser) ── */}
      {animating && active.map((id) => (
        <Packet key={`${id}-${packetKey}`} pathD={PATHS[id]} color={COLORS[id]} cycle={packetKey} />
      ))}

      {/* ── Blocks ── */}
      <Block b="pc"
        label="PC"
        sublabel={state ? `${state.pc}` : '—'}
        active={isActive('pc-to-imem') || isActive('pc-increment')}
      />
      <Block b="imem"
        label="INSTR MEM"
        sublabel={state ? `0x${state.instr.toString(16).toUpperCase().padStart(4,'0')}` : ''}
        active={isActive('pc-to-imem')}
      />
      <Block b="cu"
        label="CTRL UNIT"
        sublabel={state?.opName ?? ''}
        active={isActive('imem-to-cu')}
      />
      <Block b="regs"
        label="REGISTERS"
        active={isActive('alu-to-regs') || isActive('dmem-to-regs') || isActive('cu-to-regs')}
      />
      <Block b="alu"
        label="ALU"
        sublabel={state ? `= ${state.aluResult}` : ''}
        active={isActive('regs-to-alu') || isActive('imm-to-alu')}
      />
      <Block b="flags"
        label="FLAGS"
        sublabel={state ? `Z${state.flagZero?1:0} N${state.flagNeg?1:0} C${state.flagCarry?1:0}` : ''}
        active={isActive('alu-to-flags')}
      />
      <Block b="dmem"
        label="DATA MEM"
        active={isActive('regs-to-dmem') || isActive('alu-to-dmem-addr') || isActive('dmem-to-regs')}
      />

      {/* ── Register values inside REGS block ── */}
      {state && Array.from({ length: 8 }, (_, i) => {
        const bx = BLOCKS.regs.x + 7;
        const ry = BLOCKS.regs.y + 13 + i * 13;
        const changed = state.changedRegs.includes(i);
        return (
          <g key={i}>
            {changed && (
              <motion.rect
                x={bx - 2} y={ry - 8} width={BLOCKS.regs.w - 10} height={12}
                rx={2} fill="#1d4ed8"
                initial={{ opacity: 0 }} animate={{ opacity: [0, 1, 0.6] }}
                transition={{ duration: 0.5 }}
              />
            )}
            <text
              x={bx + 3} y={ry}
              fill={changed ? '#93c5fd' : '#475569'}
              fontSize={9} fontFamily="monospace"
              style={{ userSelect: 'none' }}
            >
              {`R${i}=${i === 0 ? 0 : state.regs[i]}`}
            </text>
          </g>
        );
      })}

      {/* ── Data memory changed indicator ── */}
      {state?.changedMem.map((addr) => (
        <motion.text
          key={addr}
          x={cx('dmem')} y={ty('dmem') + 16}
          textAnchor="middle"
          fill="#fbbf24" fontSize={9} fontFamily="monospace"
          initial={{ opacity: 0 }} animate={{ opacity: [0, 1, 0] }}
          transition={{ duration: 0.8 }}
          style={{ userSelect: 'none' }}
        >
          {`[${addr}]←${state.dataMem[addr]}`}
        </motion.text>
      ))}

      {/* ── Legend: path labels on hover (static, helps readability) ── */}
      {state && (
        <text
          x={W - 8} y={H - 8}
          textAnchor="end" fill="#1e293b"
          fontSize={9} fontFamily="monospace"
          style={{ userSelect: 'none' }}
        >
          {`cycle ${state.cycle}`}
        </text>
      )}
    </svg>
  );
}
