; NexaCPU — Program 3: Fibonacci Sequence
; Compute and store F(2) through F(7) in data memory addresses 2-7
; F(0)=0 (seed in R1), F(1)=1 (seed in R2)
; Expected memory: mem[2]=1, mem[3]=2, mem[4]=3, mem[5]=5, mem[6]=8, mem[7]=13

    LOADI R1, 0         ; R1 = F(n-2) = F(0) = 0
    LOADI R2, 1         ; R2 = F(n-1) = F(1) = 1
    LOADI R4, 2         ; R4 = memory address pointer (start at 2)
    LOADI R5, 8         ; R5 = loop limit (stop when addr reaches 8)
    LOADI R6, 1         ; R6 = address increment step
loop:
    CMP   R4, R5        ; is address == limit?
    BEQ   done          ; if yes, we're done
    ADD   R3, R1, R2    ; R3 = F(n) = F(n-2) + F(n-1)
    STORE R4, R3        ; mem[R4] = R3
    MOV   R1, R2        ; slide window: R1 = old F(n-1)
    MOV   R2, R3        ; R2 = new F(n)
    ADD   R4, R4, R6    ; advance memory address
    JMP   loop
done:
    HALT
