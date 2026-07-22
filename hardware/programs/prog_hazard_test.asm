; NexaCPU — Data Hazard Forwarding Test
;
; This program deliberately creates back-to-back RAW (Read-After-Write)
; data hazards. Without forwarding, the pipeline would read stale register
; values and produce wrong results.
;
; With forwarding:
;   LOADI R1, 5     → writes R1=5 in EX (cycle 2)
;   ADD R2, R1, R1  → reads R1 in EX (cycle 3) — forwarded from cycle 2 ✓
;   ADD R3, R2, R1  → reads R2 in EX (cycle 4) — forwarded from cycle 3 ✓
;
; Expected results: R1=5, R2=10, R3=15
;
; Without forwarding: R1=0 (stale), R2=0, R3=0 — every result would be wrong.
; So this test is a definitive pass/fail for the forwarding logic.

    LOADI R1, 5         ; R1 = 5
    ADD   R2, R1, R1    ; R2 = R1 + R1 = 10  ← R1 forwarded from previous
    ADD   R3, R2, R1    ; R3 = R2 + R1 = 15  ← R2 forwarded from previous
    HALT
