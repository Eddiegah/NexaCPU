; NexaCPU — Program: Multiplication via Repeated Addition
;
; Computes A * B by adding A to itself B times.
; This is how you multiply on a CPU that only has ADD — which is how
; early CPUs and microcontrollers did it before hardware multipliers existed.
;
; Computes: 7 * 9 = 63
;
; Register use:
;   R1 = multiplicand (A = 7, the value being added)
;   R2 = multiplier   (B = 9, the loop count)
;   R3 = product      (accumulator, starts at 0)
;   R4 = loop counter (counts down from B to 0)
;   R5 = step (1)
;
; Loop structure:
;   while counter > 0:
;     product += multiplicand
;     counter--
;
; Expected result: R3 = 63

    LOADI R1, 7         ; multiplicand = 7
    LOADI R2, 9         ; multiplier   = 9
    LOADI R3, 0         ; product      = 0
    MOV   R4, R2        ; counter = multiplier (copy R2 → R4)
    LOADI R5, 1         ; step = 1

loop:
    CMP   R4, R0        ; counter == 0?
    BEQ   done
    ADD   R3, R3, R1    ; product += multiplicand
    SUB   R4, R4, R5    ; counter--
    JMP   loop

done:
    HALT                ; R3 = 7 * 9 = 63
