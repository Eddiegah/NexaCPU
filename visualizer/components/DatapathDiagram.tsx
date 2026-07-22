'use client';

import { motion, AnimatePresence } from 'framer-motion';
import { CPUState, ActivePath } from '@/lib/cpuModel';

interface Props {
  state: CPUState | null;
  animating: boolean;
}

// ---------------------------------------------------------------------------
// Layout constants — positions of every block in the SVG
// ---------------------------------------------------------------------------
const W = 900, H = 560;

const BLOCKS = {
  pc:      { x: 30,  y: 220, w: 80,  h: 50 },
  imem:    { x: 160, y: 140, w: 110, h: 70 },
  cu:      { x: 160, y: 260, w: 110, h: 80 },
  regs:    { x: 360, y: 140, w: 110, h: 120 },
  alu:     { x: 560, y: 200, w: 110, h: 80 },
  flags:   { x: 560, y: 360, w: 110, h: 60 },
  dmem:    { x: 720, y: 140, w: 110, h: 100 },
  mux:     { x: 680, y: 310, w:  60, h:  40 },
} as const;

type BlockKey = keyof typeof BLOCKS;

function cx(b: BlockKey) { return BLOCKS[b].x + BLOCKS[b].w / 2; }
function cy(b: BlockKey) { return BLOCKS[b].y + BLOCKS[b].h / 2; }
function right(b: BlockKey) { return BLOCKS[b].x + BLOCKS[b].w; }
function left(b: BlockKey)  { return BLOCKS[b].x; }
function top(b: BlockKey)   { return BLOCKS[b].y; }
function bottom(b: BlockKey){ return BLOCKS[b].y + BLOCKS[b].h; }

// ---------------------------------------------------------------------------
// Path definitions connecting the blocks
// ---------------------------------------------------------------------------
const PATH_DEFS: Record<ActivePath, string> = {
  'pc-to-imem': `M ${right('pc')} ${cy('pc')} L ${left('imem')} ${cy('imem')}`,
  'imem-to-cu': `M ${cx('imem')} ${bottom('imem')} L ${cx('cu')} ${top('cu')}`,
  'cu-to-regs': `M ${right('cu')} ${cy('cu')} L ${left('regs')} ${cy('regs') + 20}`,
  'regs-to-alu': `M ${right('regs')} ${cy('regs') - 10} L ${left('alu')} ${cy('alu')}`,
  'imm-to-alu': `M ${cx('cu')} ${bottom('cu') + 10} C ${cx('cu')} ${cy('alu') + 60}, ${left('alu') - 30} ${cy('alu') + 30}, ${left('alu')} ${cy('alu') + 20}`,
  'alu-to-regs': `M ${left('alu')} ${cy('alu') - 10} C ${cx('regs') + 20} ${cy('regs') - 60}, ${cx('regs') + 20} ${cy('regs') - 50}, ${right('regs')} ${cy('regs') - 20}`,
  'alu-to-flags': `M ${cx('alu')} ${bottom('alu')} L ${cx('flags')} ${top('flags')}`,
  'regs-to-dmem': `M ${right('regs')} ${cy('regs') + 20} C ${cx('alu') + 20} ${cy('regs') + 20}, ${cx('dmem') - 20} ${cy('dmem') + 20}, ${left('dmem')} ${cy('dmem') + 20}`,
  'dmem-to-regs': `M ${left('dmem')} ${cy('dmem') - 20} C ${cx('alu') - 20} ${cy('dmem') - 20}, ${right('regs') + 20} ${cy('regs') - 20}, ${right('regs')} ${cy('regs') - 30}`,
  'alu-to-dmem-addr': `M ${right('alu')} ${cy('alu')} L ${left('dmem')} ${cy('dmem')}`,
  'branch-taken': `M ${cx('flags')} ${bottom('flags') + 10} C ${cx('flags')} ${H - 30}, 50 ${H - 30}, ${cx('pc')} ${bottom('pc')}`,
  'pc-increment': `M ${left('pc')} ${cy('pc')} C -20 ${cy('pc')}, -20 ${cy('pc') - 60}, ${cx('pc')} ${top('pc')}`,
};

const PATH_COLORS: Record<ActivePath, string> = {
  'pc-to-imem':        '#38bdf8', // sky
  'imem-to-cu':        '#818cf8', // indigo
  'cu-to-regs':        '#a78bfa', // violet
  'regs-to-alu':       '#34d399', // emerald
  'imm-to-alu':        '#fb923c', // orange
  'alu-to-regs':       '#4ade80', // green
  'alu-to-flags':      '#f472b6', // pink
  'regs-to-dmem':      '#fbbf24', // amber
  'dmem-to-regs':      '#22d3ee', // cyan
  'alu-to-dmem-addr':  '#f87171', // red
  'branch-taken':      '#c084fc', // purple
  'pc-increment':      '#94a3b8', // slate
};

// ---------------------------------------------------------------------------
// Animated signal packet travelling along a path
// ---------------------------------------------------------------------------
function SignalPacket({ pathId, color }: { pathId: string; color: string }) {
  return (
    <motion.circle
      r={6}
      fill={color}
      style={{ filter: `drop-shadow(0 0 6px ${color})` }}
      initial={{ offsetDistance: '0%', opacity: 1 }}
      animate={{ offsetDistance: '100%', opacity: 0 }}
      transition={{ duration: 0.7, ease: 'easeInOut' }}
      // CSS motion path — attach to the SVG path element
      // We use a foreignObject trick: just use offsetPath via inline style
    />
  );
}

// ---------------------------------------------------------------------------
// Block component
// ---------------------------------------------------------------------------
function Block({
  b, label, sublabel, highlight, value,
}: {
  b: BlockKey;
  label: string;
  sublabel?: string;
  highlight?: boolean;
  value?: string;
}) {
  const { x, y, w, h } = BLOCKS[b];
  return (
    <g>
      <motion.rect
        x={x} y={y} width={w} height={h} rx={6}
        fill={highlight ? '#1e3a5f' : '#0f172a'}
        stroke={highlight ? '#38bdf8' : '#334155'}
        strokeWidth={highlight ? 2 : 1}
        animate={{ stroke: highlight ? '#38bdf8' : '#334155' }}
        transition={{ duration: 0.3 }}
      />
      <text x={x + w / 2} y={y + h / 2 - (sublabel || value ? 8 : 0)}
        textAnchor="middle" dominantBaseline="middle"
        fill="#e2e8f0" fontSize={12} fontFamily="monospace" fontWeight="600">
        {label}
      </text>
      {sublabel && (
        <text x={x + w / 2} y={y + h / 2 + 10}
          textAnchor="middle" dominantBaseline="middle"
          fill="#94a3b8" fontSize={10} fontFamily="monospace">
          {sublabel}
        </text>
      )}
      {value && (
        <text x={x + w / 2} y={y + h / 2 + 12}
          textAnchor="middle" dominantBaseline="middle"
          fill="#38bdf8" fontSize={11} fontFamily="monospace" fontWeight="700">
          {value}
        </text>
      )}
    </g>
  );
}

// ---------------------------------------------------------------------------
// Main component
// ---------------------------------------------------------------------------
export default function DatapathDiagram({ state, animating }: Props) {
  const activePaths = state?.activePaths ?? [];

  // Build path elements as defs so we can reference them for motion
  const pathElements = Object.entries(PATH_DEFS).map(([id, d]) => (
    <path key={id} id={`dp-${id}`} d={d} fill="none" stroke="transparent" />
  ));

  return (
    <svg
      viewBox={`0 0 ${W} ${H}`}
      className="w-full h-full"
      style={{ background: 'transparent' }}
    >
      <defs>
        <marker id="arrow" markerWidth="6" markerHeight="6" refX="5" refY="3" orient="auto">
          <path d="M0,0 L6,3 L0,6 Z" fill="#475569" />
        </marker>
        <marker id="arrow-active" markerWidth="6" markerHeight="6" refX="5" refY="3" orient="auto">
          <path d="M0,0 L6,3 L0,6 Z" fill="#38bdf8" />
        </marker>
        {/* Hidden path defs for motion */}
        {pathElements}
      </defs>

      {/* ── Static connection lines ── */}
      {(Object.entries(PATH_DEFS) as [ActivePath, string][]).map(([id, d]) => {
        const isActive = activePaths.includes(id) && animating;
        const color = PATH_COLORS[id];
        return (
          <motion.path
            key={id} d={d} fill="none"
            stroke={isActive ? color : '#1e293b'}
            strokeWidth={isActive ? 2.5 : 1.5}
            strokeDasharray={isActive ? undefined : '4,4'}
            markerEnd={isActive ? 'url(#arrow-active)' : 'url(#arrow)'}
            animate={{ stroke: isActive ? color : '#1e293b', strokeWidth: isActive ? 2.5 : 1.5 }}
            transition={{ duration: 0.35 }}
          />
        );
      })}

      {/* ── Animated signal packets ── */}
      <AnimatePresence>
        {animating && activePaths.map((id) => {
          const d = PATH_DEFS[id];
          const color = PATH_COLORS[id];
          if (!d) return null;
          return (
            <motion.circle
              key={`pkt-${id}-${state?.cycle}`}
              r={5}
              fill={color}
              style={{
                filter: `drop-shadow(0 0 5px ${color})`,
                offsetPath: `path("${d}")`,
                offsetDistance: '0%',
              } as React.CSSProperties}
              initial={{ opacity: 1 }}
              animate={{ opacity: [1, 1, 0] }}
              transition={{ duration: 0.75, times: [0, 0.7, 1] }}
            />
          );
        })}
      </AnimatePresence>

      {/* ── CPU Blocks ── */}
      <Block b="pc"   label="PC" value={state ? `${state.pc}` : '–'} highlight={animating} />
      <Block b="imem" label="INSTR MEM"
        sublabel={state ? `0x${state.instr.toString(16).toUpperCase().padStart(4,'0')}` : ''}
        highlight={activePaths.includes('pc-to-imem') && animating} />
      <Block b="cu"   label="CONTROL UNIT"
        sublabel={state?.opName ?? ''}
        highlight={activePaths.includes('imem-to-cu') && animating} />
      <Block b="regs" label="REGISTERS"
        highlight={activePaths.includes('alu-to-regs') && animating} />
      <Block b="alu"  label="ALU"
        sublabel={state ? `→ ${state.aluResult}` : ''}
        highlight={activePaths.includes('regs-to-alu') && animating} />
      <Block b="flags" label="FLAGS"
        sublabel={state ? `Z:${state.flagZero?1:0} N:${state.flagNeg?1:0} C:${state.flagCarry?1:0}` : ''}
        highlight={activePaths.includes('alu-to-flags') && animating} />
      <Block b="dmem" label="DATA MEM"
        highlight={(activePaths.includes('regs-to-dmem') || activePaths.includes('dmem-to-regs')) && animating} />

      {/* ── Register names inside the register file block ── */}
      {state && [0,1,2,3,4,5,6,7].map((i) => {
        const bx = BLOCKS.regs.x + 6;
        const by = BLOCKS.regs.y + 14 + i * 13;
        const changed = state.changedRegs.includes(i);
        return (
          <g key={i}>
            <motion.rect
              x={bx - 2} y={by - 9} width={BLOCKS.regs.w - 8} height={12}
              rx={2} fill={changed ? '#1d4ed8' : 'transparent'}
              animate={{ fill: changed ? '#1d4ed8' : 'transparent' }}
              transition={{ duration: 0.4 }}
            />
            <text x={bx + 4} y={by}
              fill={changed ? '#93c5fd' : '#64748b'} fontSize={9} fontFamily="monospace">
              {`R${i}=${i === 0 ? '0' : state.regs[i]}`}
            </text>
          </g>
        );
      })}

      {/* ── Instruction label near PC ── */}
      {state && (
        <text x={cx('pc')} y={top('pc') - 8}
          textAnchor="middle" fill="#94a3b8" fontSize={10} fontFamily="monospace">
          {`PC=${state.pc}`}
        </text>
      )}
    </svg>
  );
}
