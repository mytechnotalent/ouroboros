; ==============================================================================
; Project:       The Ouroboros Engine
; Author:        Kevin Thomas
; E-Mail:        ket189@pitt.edu
; Version:       1.0.0
; Date:          2026-06-26
; Target Device: ATmega328P
; Clock Freq:    8 MHz
; Toolchain:     avr-as, avr-ld, avrdude
; Description:   Variables
; ==============================================================================

; ==============================================================================
; DATA SECTION
; ==============================================================================
.section .data                          ; Declare section

; ==============================================================================
; BSS SECTION
; ==============================================================================
.section .bss                           ; Declare section

; ==============================================================================
; DATA DEFINITIONS
; ==============================================================================
round_keys:  .space 272                 ; 34 round keys x 8 bytes each
l_buf:       .space 32                  ; Key schedule circular buf (4 x 8 bytes)
input_buf:   .space 32                  ; UART receive buffer (padded to 32)
hash_buf:    .space 16                  ; Computed Davies-Meyer hash
ctr_buf:     .space 16                  ; CTR counter block (nonce || counter)
result_buf:  .space 48                  ; Final XOR output (plaintext or garbage)
sys_state:   .space 1                   ; Current mode (0=anim,1=red,2=green,3=blue,4=input)
prev_state:  .space 1                   ; Saved mode before entering input
anim_idx:    .space 1                   ; Animation sub-colour (0=R,1=G,2=B)
uart_idx:    .space 1                   ; UART buffer write index
anim_timer:  .space 2                   ; Software animation counter (16-bit)
input_timer: .space 2                   ; Input inactivity timeout counter (16-bit)
