; NexaCPU — Program 2: Countdown Loop
; Count R1 from 5 down to 0, counting iterations in R3
; Expected result: R1=0, R2=1, R3=5 (loop ran 5 times), R4=1

    LOADI R1, 5         ; R1 = countdown start
    LOADI R2, 1         ; R2 = step (decrement by 1)
    LOADI R3, 0         ; R3 = iteration counter (starts at 0)
    LOADI R4, 1         ; R4 = 1 (used to increment R3)
loop:
    CMP   R1, R0        ; compare R1 to 0 (R0 is hardwired zero)
    BEQ   done          ; if R1 == 0, jump to done
    SUB   R1, R1, R2    ; R1 -= 1
    ADD   R3, R3, R4    ; R3 += 1 (count this iteration)
    JMP   loop          ; go back to top
done:
    HALT
