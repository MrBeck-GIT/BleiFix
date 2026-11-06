; BLEIFIX.COM - Patcher for STARTH.EXE (Bleifuss / Screamer renderer crashes)
; nasm -f bin BLEIFIX.ASM -o BLEIFIX.COM
bits 16
org 100h
SIZE_LO equ 0xCAAB
SIZE_HI equ 0x000F
SUM_O equ 0x05858a04
SUM_1 equ 0x0585bcff
SUM_N equ 0x0585f0cc

start:  cld
        mov dx,m_title
        call print
        mov word [tbl],t_orig
        mov word [srclo],SUM_O & 0xFFFF
        mov word [srchi],SUM_O >> 16
        call check              ; AL: 0=source 1=patched 2=unknown 3=not found
        cmp al,3
        je .nofile
        cmp al,1
        je .done
        cmp al,0
        je .doit
        mov word [tbl],t_v1
        mov word [srclo],SUM_1 & 0xFFFF
        mov word [srchi],SUM_1 >> 16
        call check
        cmp al,0
        jne .unknown
        mov dx,m_v1
        call print
.doit:  mov dx,f_exe            ; can STARTH.EXE be written at all?
        mov ax,0x3D02
        int 21h
        jc .ro
        mov bx,ax
        mov ah,0x3E
        int 21h
        call backup
        jc .fail
        call patch
        jc .wfail
        call check
        cmp al,1
        jne .wfail
        mov dx,m_ok
        call print
        mov al,0
        jmp exit
.nofile: mov dx,m_nofile
        jmp .err
.done:  mov dx,m_already
        call print
        mov al,0
        jmp exit
.unknown: mov dx,m_unknown
        jmp .err
.wfail: mov dx,m_wfail
        jmp .err
.ro:    mov dx,m_ro
        jmp .err
.fail:  mov dx,m_bfail
.err:   call print
        mov al,1
exit:   mov ah,0x4C
        int 21h

print:  mov ah,9
        int 21h
        ret

; Determine the state of the EXE
check:  mov dx,f_exe
        mov ax,0x3D00
        int 21h
        jnc .open
        mov al,3
        ret
.open:  mov [handle],ax
        mov bx,ax
        mov ax,0x4202
        xor cx,cx
        xor dx,dx
        int 21h
        jc .bad
        cmp ax,SIZE_LO
        jne .bad
        cmp dx,SIZE_HI
        jne .bad
        mov ax,0x4200
        xor cx,cx
        xor dx,dx
        int 21h
        jc .bad
        xor ax,ax
        mov [sumlo],ax
        mov [sumhi],ax
.rd:    mov bx,[handle]
        mov cx,0x8000
        mov dx,buf
        mov ah,0x3F
        int 21h
        jc .bad
        cmp ax,0
        je .rdone
        mov cx,ax
        mov si,buf
.sum:   lodsb
        mov ah,0
        add [sumlo],ax
        adc word [sumhi],0
        loop .sum
        jmp .rd
.rdone: mov byte [isorig],1
        mov byte [isnew],1
        mov si,[tbl]
.next:  mov dx,[si]
        mov cx,[si+2]
        cmp cx,0xFFFF
        je .eval
        mov bx,[handle]
        mov ax,0x4200
        int 21h
        jc .bad
        xor cx,cx
        mov cl,[si+4]
        mov dx,buf
        mov ah,0x3F
        int 21h
        jc .bad
        cmp ax,cx
        jne .bad
        add si,5
        mov di,buf
        push cx
        push si
        repe cmpsb
        pop si
        pop cx
        je .o1
        mov byte [isorig],0
.o1:    add si,cx
        mov di,buf
        push cx
        push si
        repe cmpsb
        pop si
        pop cx
        je .n1
        mov byte [isnew],0
.n1:    add si,cx
        jmp .next
.eval:  mov bx,[handle]
        mov ah,0x3E
        int 21h
        mov ax,[sumlo]
        mov dx,[sumhi]
        cmp byte [isnew],1
        jne .eo
        cmp ax,SUM_N & 0xFFFF
        jne .eu
        cmp dx,SUM_N >> 16
        jne .eu
        mov al,1
        ret
.eo:    cmp byte [isorig],1
        jne .eu
        cmp ax,[srclo]
        jne .eu
        cmp dx,[srchi]
        jne .eu
        mov al,0
        ret
.eu:    mov al,2
        ret
.bad:   mov bx,[handle]
        mov ah,0x3E
        int 21h
        mov al,2
        ret

; Create backup STARTH.BAK (an existing one is never touched)
backup: mov dx,f_bak
        mov ax,0x3D00
        int 21h
        jc .create
        mov bx,ax
        mov ah,0x3E
        int 21h
        mov dx,m_bakex
        call print
        clc
        ret
.create: mov dx,f_exe
        mov ax,0x3D00
        int 21h
        jc .e0
        mov [handle],ax
        mov dx,f_bak
        xor cx,cx
        mov ah,0x3C
        int 21h
        jc .e1
        mov [handle2],ax
.loop:  mov bx,[handle]
        mov cx,0x8000
        mov dx,buf
        mov ah,0x3F
        int 21h
        jc .e2
        cmp ax,0
        je .fin
        mov cx,ax
        mov bx,[handle2]
        mov dx,buf
        mov ah,0x40
        int 21h
        jc .e2
        cmp ax,cx
        jne .e2
        jmp .loop
.fin:   mov bx,[handle2]
        mov ah,0x3E
        int 21h
        jc .e1b
        mov bx,[handle]
        mov ah,0x3E
        int 21h
        mov dx,m_bak
        call print
        clc
        ret
.e2:    mov bx,[handle2]
        mov ah,0x3E
        int 21h
.e1b:   mov dx,f_bak
        mov ah,0x41
        int 21h
.e1:    mov bx,[handle]
        mov ah,0x3E
        int 21h
.e0:    stc
        ret

patch:  mov dx,f_exe
        mov ax,0x3D02
        int 21h
        jc .e
        mov [handle],ax
        mov si,[tbl]
.next:  mov dx,[si]
        mov cx,[si+2]
        cmp cx,0xFFFF
        je .fin
        mov bx,[handle]
        mov ax,0x4200
        int 21h
        jc .ec
        xor cx,cx
        mov cl,[si+4]
        add si,5
        add si,cx
        mov dx,si
        mov ah,0x40
        int 21h
        jc .ec
        cmp ax,cx
        jne .ec
        add si,cx
        jmp .next
.fin:   mov bx,[handle]
        mov ah,0x3E
        int 21h
        jc .e
        clc
        ret
.ec:    mov bx,[handle]
        mov ah,0x3E
        int 21h
.e:     stc
        ret

f_exe   db 'STARTH.EXE',0
f_bak   db 'STARTH.BAK',0
m_title db 'BLEIFIX 1.1 - Crash fix for STARTH.EXE (Bleifuss / Screamer renderer)',13,10,13,10,'$'
m_nofile db 'ERROR: STARTH.EXE not found. Please run BLEIFIX in the game folder.',13,10,'$'
m_already db 'STARTH.EXE is already patched. Nothing was changed.',13,10,'$'
m_unknown db 'ERROR: Unknown version of STARTH.EXE. Nothing was changed.',13,10,'$'
m_bfail db 'ERROR: Backup failed (disk full or write-protected?). Nothing was changed.',13,10,'$'
m_wfail db 'ERROR: Patching failed! Restore STARTH.EXE from STARTH.BAK.',13,10,'$'
m_bakex db 'STARTH.BAK already exists and was left unchanged.',13,10,'$'
m_bak   db 'Backup copy STARTH.BAK created.',13,10,'$'
m_v1    db 'Found STARTH.EXE patched with BLEIFIX 1.0, updating it.',13,10,'$'
m_ro    db 'ERROR: STARTH.EXE is write-protected. Nothing was changed.',13,10,'$'
m_ok    db 'STARTH.EXE was patched successfully.',13,10,'$'
isorig  db 0
isnew   db 0
handle  dw 0
handle2 dw 0
sumlo   dw 0
tbl     dw 0
srclo   dw 0
srchi   dw 0
sumhi   dw 0
t_orig:
dw 0x2b14,0x0000
db 2
db 147,186
db 0,188
dw 0x2b46,0x0000
db 1
db 4
db 6
dw 0xd418,0x0000
db 3
db 1,200,211
db 3,192,114
dw 0xe2da,0x0000
db 3
db 1,200,211
db 3,192,114
dw 0x1f33,0x0001
db 3
db 1,200,211
db 3,192,114
dw 0x471f,0x0001
db 3
db 1,200,211
db 3,192,114
dw 0x75bc,0x000d
db 5
db 43,239,77,121,207
db 233,64,237,1,0
dw 0x81b4,0x000d
db 5
db 131,196,24,235,48
db 233,192,225,1,0
dw 0x82b7,0x000d
db 5
db 131,196,24,233,42
db 233,189,224,1,0
dw 0x835e,0x000d
db 5
db 131,196,24,233,131
db 233,22,224,1,0
dw 0x8466,0x000d
db 5
db 138,223,102,139,214
db 232,130,222,1,0
dw 0x0200,0x000e
db 5
db 131,196,24,235,68
db 233,90,97,1,0
dw 0x031e,0x000e
db 5
db 131,196,24,233,35
db 233,60,96,1,0
dw 0x03cb,0x000e
db 5
db 131,196,24,233,118
db 233,143,95,1,0
dw 0x04fc,0x000e
db 5
db 138,223,102,139,214
db 232,236,93,1,0
dw 0x4f95,0x000e
db 5
db 193,255,16,43,239
db 232,123,19,1,0
dw 0x61ba,0x000e
db 5
db 131,196,24,235,46
db 233,173,1,1,0
dw 0x62bc,0x000e
db 5
db 131,196,24,233,41
db 233,171,0,1,0
dw 0x635d,0x000e
db 5
db 131,196,24,233,136
db 233,10,0,1,0
dw 0x644b,0x000e
db 5
db 139,211,193,251,8
db 232,167,254,0,0
dw 0x7068,0x000e
db 5
db 131,196,24,235,48
db 233,25,243,0,0
dw 0x716b,0x000e
db 5
db 131,196,24,233,42
db 233,22,242,0,0
dw 0x7212,0x000e
db 5
db 131,196,24,233,131
db 233,111,241,0,0
dw 0x7316,0x000e
db 5
db 138,223,102,139,214
db 232,210,239,0,0
dw 0x62c0,0x000f
db 12
db 0,0,0,0,0,0,0,0,0,0,0,0
db 133,255,121,4,1,253,49,255,129,255,223,1
dw 0x62ce,0x000f
db 5
db 0,0,0,0,0
db 126,7,191,223,1
dw 0x62d5,0x000f
db 8
db 0,0,0,0,0,0,0,0
db 49,237,1,253,129,253,223,1
dw 0x62df,0x000f
db 5
db 0,0,0,0,0
db 126,5,189,223,1
dw 0x62e6,0x000f
db 62
db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
db 41,253,121,2,49,237,195,138,223,102,139,214,233,201,255,255,255,139,211,193,251,8,233,191,255,255,255,43,239,77,121,5,233,182,18,254,255,232,176,255,255,255,233,123,18,254,255,193,255,16,43,239,120,7,232,159,255,255,255,133,237,195
dw 0x6330,0x000f
db 3
db 0,0,0
db 80,82,232
dw 0x6337,0x000f
db 5
db 0,0,0,0,0
db 88,45,47,132,3
dw 0x633d,0x000f
db 86
db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
db 247,216,141,68,4,12,133,192,127,2,49,192,193,232,3,186,171,170,170,170,247,226,209,234,66,57,209,118,2,137,209,90,88,195,131,196,24,232,201,255,255,255,233,221,158,254,255,131,196,24,232,188,255,255,255,233,116,254,254,255,131,196,24,232,175,255,255,255,233,99,30,254,255,131,196,24,232,162,255,255,255,233,10,13,255,255
dw 0xffff,0xffff
t_v1:
dw 0x81b4,0x000d
db 5
db 131,196,24,235,48
db 233,192,225,1,0
dw 0x82b7,0x000d
db 5
db 131,196,24,233,42
db 233,189,224,1,0
dw 0x835e,0x000d
db 5
db 131,196,24,233,131
db 233,22,224,1,0
dw 0x0200,0x000e
db 5
db 131,196,24,235,68
db 233,90,97,1,0
dw 0x031e,0x000e
db 5
db 131,196,24,233,35
db 233,60,96,1,0
dw 0x03cb,0x000e
db 5
db 131,196,24,233,118
db 233,143,95,1,0
dw 0x61ba,0x000e
db 5
db 131,196,24,235,46
db 233,173,1,1,0
dw 0x62bc,0x000e
db 5
db 131,196,24,233,41
db 233,171,0,1,0
dw 0x635d,0x000e
db 5
db 131,196,24,233,136
db 233,10,0,1,0
dw 0x7068,0x000e
db 5
db 131,196,24,235,48
db 233,25,243,0,0
dw 0x716b,0x000e
db 5
db 131,196,24,233,42
db 233,22,242,0,0
dw 0x7212,0x000e
db 5
db 131,196,24,233,131
db 233,111,241,0,0
dw 0x6330,0x000f
db 3
db 0,0,0
db 80,82,232
dw 0x6337,0x000f
db 5
db 0,0,0,0,0
db 88,45,47,132,3
dw 0x633d,0x000f
db 86
db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
db 247,216,141,68,4,12,133,192,127,2,49,192,193,232,3,186,171,170,170,170,247,226,209,234,66,57,209,118,2,137,209,90,88,195,131,196,24,232,201,255,255,255,233,221,158,254,255,131,196,24,232,188,255,255,255,233,116,254,254,255,131,196,24,232,175,255,255,255,233,99,30,254,255,131,196,24,232,162,255,255,255,233,10,13,255,255
dw 0xffff,0xffff

buf:
