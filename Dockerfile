# syntax=docker/dockerfile:1.6

########################################
# Build stage
########################################
FROM debian:13-slim AS builder

LABEL version="1.0"
LABEL org.opencontainers.image.source=https://github.com/nishidemasami/smaller-docker-helloworld
LABEL org.opencontainers.image.description="very small Dockerfile for hello world"

LABEL maintainer="NISHIDE, Masami <nishidemasami@gmail.com>"


RUN apt-get update && \
    apt-get install -y nasm

WORKDIR /src

RUN <<EOF
cat <<- '_ASM_' > hello_amd64.nasm
; hello_amd64.nasm - minimal ELF64 Linux "Hello, World!\n"
; assemble: nasm -f bin hello_amd64.nasm -o hello
; run:      chmod +x hello && ./hello

BITS 64
org 0x400000

ehdr:
    db 0x7F, "ELF"              ; e_ident[0..3]
    db 2                        ; EI_CLASS   = ELFCLASS64
    db 1                        ; EI_DATA    = ELFDATA2LSB
    db 1                        ; EI_VERSION = EV_CURRENT
    db 0                        ; EI_OSABI   = System V
    db 0                        ; EI_ABIVERSION
    times 7 db 0                ; padding to 16 bytes

    dw 2                        ; e_type    = ET_EXEC
    dw 0x3E                     ; e_machine = EM_X86_64
    dd 1                        ; e_version = EV_CURRENT
    dq _start                   ; e_entry
    dq phdr - $$                ; e_phoff
    dq 0                        ; e_shoff
    dd 0                        ; e_flags
    dw ehdrsize                 ; e_ehsize
    dw phdrsize                 ; e_phentsize
    dw 1                        ; e_phnum
    dw 0                        ; e_shentsize
    dw 0                        ; e_shnum
    dw 0                        ; e_shstrndx
ehdrsize  equ $ - ehdr

phdr:
    dd 1                        ; p_type  = PT_LOAD
    dd 5                        ; p_flags = PF_R | PF_X
    dq 0                        ; p_offset
    dq $$                       ; p_vaddr
    dq $$                       ; p_paddr
    dq filesize                 ; p_filesz
    dq filesize                 ; p_memsz
    dq 0x1000                   ; p_align
phdrsize equ $ - phdr

_start:
    ; write(1, msg, msglen)
    push byte 1
    pop  rax                    ; rax = 1 (SYS_write)
    push byte 1
    pop  rdi                    ; rdi = 1 (stdout)
    mov  esi, msg               ; rsi = &msg  (zero-extended imm32)
    push byte msglen
    pop  rdx                    ; rdx = msglen
    syscall

    ; exit(0)
    mov  al, 60                 ; SYS_exit
    xor  edi, edi               ; status = 0
    syscall

msg:
    db "Hello, World!", 10      ; 10 = LF(\n)
msglen  equ $ - msg

filesize equ $ - $$
_ASM_
EOF


RUN nasm -f bin -o hello_amd64 hello_amd64.nasm
RUN chmod +x hello_amd64

########################################
# Runtime stage
########################################
FROM scratch

COPY --from=builder /src/hello_amd64 /o

ENTRYPOINT ["/o"]

########################################
# How to build
# $ docker buildx build --platform linux/amd64 -t helloworld-nasm-amd64 -f helloworld-dockerfile --load .
########################################