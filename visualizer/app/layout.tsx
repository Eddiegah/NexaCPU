import type { Metadata } from 'next';
import { JetBrains_Mono } from 'next/font/google';
import './globals.css';

const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'NexaCPU — A Real CPU, Built From Scratch',
  description:
    'An animated, interactive visualization of NexaCPU — a 16-bit RISC processor designed from first principles in Verilog, verified with 124 automated tests, and visualized instruction by instruction.',
  keywords: ['CPU', 'Verilog', 'RISC', 'computer architecture', 'CPU simulator', 'hardware design'],
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${jetbrainsMono.variable} dark`}>
      <body className="bg-slate-950 text-slate-100 antialiased">
        {children}
      </body>
    </html>
  );
}
