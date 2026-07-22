; NexaCPU — Program: Bubble Sort
;
; Sorts 5 values in data memory addresses 0–4 into ascending order.
; Uses the classic bubble sort algorithm: repeatedly compare adjacent
; pairs and swap if out of order, until no swaps occur in a pass.
;
; Input  (stored by this program): mem[0..4] = {5, 3, 8, 1, 4}
; Output (after sort):             mem[0..4] = {1, 3, 4, 5, 8}
;
; Register use:
;   R1 = outer loop counter (passes remaining, starts at 4)
;   R2 = inner loop pointer (current index i, 0..3)
;   R3 = inner loop limit  (N-1 = 4, shrinks each outer pass)
;   R4 = step (1)
;   R5 = mem[i]   (current element)
;   R6 = mem[i+1] (next element)
;   R7 = temp address (i+1)
;
; Algorithm:
;   for pass = N-1 downto 1:
;     for i = 0 to pass-1:
;       if mem[i] > mem[i+1]: swap them
;
; NexaCPU has no "greater-than" branch directly, but:
;   "a > b" is the same as "b < a" which is BLT after CMP b, a
;
; Program size: fits in 64 instructions.
; Expected final: mem[0]=1, mem[1]=3, mem[2]=4, mem[3]=5, mem[4]=8

    ; --- Store the unsorted array ---
    LOADI R4, 1         ; step = 1 (used throughout)

    LOADI R7, 0  ; addr 0
    LOADI R5, 5  ; value 5
    STORE R7, R5

    LOADI R7, 1
    LOADI R5, 3
    STORE R7, R5

    LOADI R7, 2
    LOADI R5, 8
    STORE R7, R5

    LOADI R7, 3
    LOADI R5, 1
    STORE R7, R5

    LOADI R7, 4
    LOADI R5, 4
    STORE R7, R5

    ; --- Bubble sort ---
    ; R1 = pass limit (starts at 4, decrements each outer loop)
    ; R3 = inner limit (same as R1 — "sort up to index R1")
    LOADI R1, 4         ; outer pass limit = N-1 = 4

outer:
    CMP   R1, R0        ; pass limit == 0? done
    BEQ   sorted
    LOADI R2, 0         ; inner index i = 0
    MOV   R3, R1        ; inner limit = current pass limit

inner:
    CMP   R2, R3        ; i == inner limit? end inner loop
    BEQ   next_pass
    LOAD  R5, R2        ; R5 = mem[i]
    ADD   R7, R2, R4    ; R7 = i+1
    LOAD  R6, R7        ; R6 = mem[i+1]

    ; Compare R5 and R6: if R5 > R6 (i.e. R6 < R5), swap
    ; CMP R6, R5 sets Negative if R6 < R5
    CMP   R6, R5
    BLT   do_swap       ; if mem[i] > mem[i+1], swap

no_swap:
    ADD   R2, R2, R4    ; i++
    JMP   inner

do_swap:
    STORE R2, R6        ; mem[i]   = R6 (the smaller value)
    STORE R7, R5        ; mem[i+1] = R5 (the larger value)
    ADD   R2, R2, R4    ; i++
    JMP   inner

next_pass:
    SUB   R1, R1, R4    ; pass limit--
    JMP   outer

sorted:
    HALT
    ; mem[0..4] = {1, 3, 4, 5, 8}
