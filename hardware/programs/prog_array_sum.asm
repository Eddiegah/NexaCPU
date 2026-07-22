; NexaCPU — Program: Array Sum
;
; Sums an array of 6 values stored in data memory addresses 0–5.
; Uses a pointer (R4) and loop to accumulate into R3.
;
; Memory layout (pre-loaded by this program):
;   mem[0] = 10
;   mem[1] = 20
;   mem[2] = 30
;   mem[3] = 40
;   mem[4] = 50
;   mem[5] = 60
;
; Expected result: R3 = 10+20+30+40+50+60 = 210
; Register use:
;   R1 = address pointer (starts at 0)
;   R2 = loop limit (6)
;   R3 = accumulator (starts at 0)
;   R4 = step (1)
;   R5 = loaded value from memory
;
; Strategy: store the array first, then loop over it.
; This demonstrates STORE + LOAD working together in a real program.

    ; --- Store the array into data memory ---
    LOADI R7, 0         ; address = 0
    LOADI R5, 10        ; value = 10
    STORE R7, R5        ; mem[0] = 10

    LOADI R7, 1
    LOADI R5, 20
    STORE R7, R5        ; mem[1] = 20

    LOADI R7, 2
    LOADI R5, 30
    STORE R7, R5        ; mem[2] = 30

    LOADI R7, 3
    LOADI R5, 40
    STORE R7, R5        ; mem[3] = 40

    LOADI R7, 4
    LOADI R5, 50
    STORE R7, R5        ; mem[4] = 50

    LOADI R7, 5
    LOADI R5, 60
    STORE R7, R5        ; mem[5] = 60

    ; --- Sum the array ---
    LOADI R1, 0         ; pointer = 0
    LOADI R2, 6         ; limit = 6
    LOADI R3, 0         ; accumulator = 0
    LOADI R4, 1         ; step = 1

loop:
    CMP   R1, R2        ; pointer == limit?
    BEQ   done
    LOAD  R5, R1        ; R5 = mem[R1]
    ADD   R3, R3, R5    ; accumulator += R5
    ADD   R1, R1, R4    ; pointer++
    JMP   loop

done:
    HALT                ; R3 = 210
