# syntax=docker/dockerfile:1.6

########################################
# Build stage
########################################
FROM debian:13-slim AS builder

LABEL version="1.1"
LABEL org.opencontainers.image.source=https://github.com/nishidemasami/smaller-docker-helloworld
LABEL org.opencontainers.image.description="very small Dockerfile for hello world"

LABEL maintainer="NISHIDE, Masami <nishidemasami@gmail.com>"

ARG TARGETARCH

RUN apt-get update

RUN case "$TARGETARCH" in \
    amd64) apt-get install -y nasm;; \
    arm64) apt-get install -y binutils-aarch64-linux-gnu;; \
    esac

WORKDIR /src

RUN cat > hello_arm64.s <<'EOF'
.global _start

.section .text
_start:

// ---- ELF Header (64 bytes) ----
.byte 0x7f,0x45,0x4c,0x46   // ELF
.byte 2,1,1,0               // 64bit, little endian
.zero 8

.hword 2                    // ET_EXEC
.hword 0xb7                 // EM_AARCH64
.word 1                     // version

.quad 0x400078             // entry point
.quad 0x40                 // program header offset
.quad 0                    // section header offset
.word 0                    // flags

.hword 64                  // ehsize
.hword 56                  // phentsize
.hword 1                   // phnum
.hword 0,0,0               // section headers unused

// ---- Program Header (56 bytes) ----
.word 1                    // PT_LOAD
.word 5                    // PF_R | PF_X
.quad 0                    // offset
.quad 0x400000             // vaddr
.quad 0                    // paddr
.quad file_end - _start    // filesz
.quad file_end - _start    // memsz
.quad 0x1000               // align

// ---- code ----
code_start:

    mov x0, #1
    adr x1, msg
    mov x2, #13
    mov x8, #64
    svc #0

    mov x0, #0
    mov x8, #93
    svc #0

msg:
    .ascii "Hello, World!\n"

file_end:
EOF

RUN cat > hello_amd64.nasm <<'EOF'
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
EOF

RUN case "$TARGETARCH" in \
    amd64) nasm -f bin -o hello hello_amd64.nasm;; \
    arm64) aarch64-linux-gnu-as -o hello_arm64.o hello_arm64.s && aarch64-linux-gnu-objcopy -O binary hello_arm64.o hello;; \
    esac

RUN chmod +x hello

########################################
# Runtime stage
########################################
FROM scratch

COPY --from=builder /src/hello /o

ENTRYPOINT ["/o"]
