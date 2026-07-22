; NexaCPU — Program 1: Basic Arithmetic
; Compute: R3 = (5 + 10) - 3 = 12
;          R4 = R3 + R3 = 24  (multiply by 2)
;          R5 = R4 AND 15 = 8 (mask lower nibble)
; Expected result: R1=5, R2=10, R3=12, R4=24, R5=8, R6=3, R7=15

    LOADI R1, 5         ; R1 = 5
    LOADI R2, 10        ; R2 = 10
    ADD   R3, R1, R2    ; R3 = 5 + 10 = 15
    LOADI R6, 3         ; R6 = 3
    SUB   R3, R3, R6    ; R3 = 15 - 3 = 12
    ADD   R4, R3, R3    ; R4 = 12 + 12 = 24
    LOADI R7, 15        ; R7 = 0x0F (mask)
    AND   R5, R4, R7    ; R5 = 24 AND 15 = 8
    HALT
