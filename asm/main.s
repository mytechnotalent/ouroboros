; ==============================================================================
; Project:       The Ouroboros Engine
; Author:        Kevin Thomas
; E-Mail:        ket189@pitt.edu
; Version:       1.0.0
; Date:          2026-06-26
; Target Device: ATmega328P
; Clock Freq:    8 MHz
; Toolchain:     avr-as, avr-ld, avrdude
; Description:   System Entry & Loop
; ==============================================================================

; ==============================================================================
; GLOBAL EXPORTS
; ==============================================================================
.global main                            ; Export symbol

; ==============================================================================
; INITIALIZED DATA (.text / Flash)
; ==============================================================================
.section .text                          ; Declare section

; ==============================================================================
; DEFINES
; ==============================================================================
.include "defines.s"                    ; Assembler directive

; ==============================================================================
; RESET VECTOR
; ==============================================================================
.org 0x0000                             ; Set origin to 0x0000
  RJMP  main                            ; Jump to main entry point

; ==============================================================================
; SUBROUTINE:  main
; ==============================================================================
; Description: Initializes the system, hardware peripherals, and SRAM,
;              then enters the main program loop.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
main:
  LDI   R16, lo8(RAMEND)                ; R16 = lo8(RAMEND)
  OUT   SPL, R16                        ; I/O[SPL] = R16
  LDI   R16, hi8(RAMEND)                ; R16 = hi8(RAMEND)
  OUT   SPH, R16                        ; I/O[SPH] = R16
  LDI   R26, lo8(0x0100)                ; X-ptr low (start of SRAM)
  LDI   R27, hi8(0x0100)                ; X-ptr high
  LDI   R16, lo8(2048)                  ; R16 = lo8(2048)
  LDI   R17, hi8(2048)                  ; R17 = hi8(2048)
  CLR   R1                              ; R1 = 0
.sram_clear:
  ST    X+, R1                          ; Store 0 and inc
  DEC   R16                             ; Decrement low byte
  BRNE  .sram_clear                     ; Loop until low is 0
  DEC   R17                             ; Decrement high byte
  BRNE  .sram_clear                     ; Loop until high is 0
  RCALL clear_reset_flags               ; Call clear_reset_flags
  RCALL uart_init                       ; Call uart_init
  RCALL config_pins                     ; Call config_pins
  CLR   R16                             ; R16 = 0
  STS   sys_state, R16                  ; sys_state = STATE_ANIM
  STS   uart_idx, R16                   ; uart_idx = 0
  STS   anim_idx, R16                   ; anim_idx = 0
  STS   prev_state, R16                 ; prev_state = 0
  STS   anim_timer, R16                 ; anim_timer = 0
  STS   anim_timer + 1, R16             ; anim_timer high = 0
  RCALL render_state                    ; Show initial boot colour
  RCALL tx_prompt                       ; Print "> " prompt

; ==============================================================================
; PROGRAM LOOP
; ==============================================================================
main_loop:
  RCALL delay_and_timers                ; Fixed delay, timers, anim advance
  RCALL handle_button                   ; Button poll + UART poll fall-through
  RJMP  main_loop                       ; Continue

; ==============================================================================
; LIBRARIES
; ==============================================================================
.include "boot.s"                       ; Assembler directive
.include "uart.s"                       ; Assembler directive
.include "delay.s"                      ; Assembler directive
.include "button.s"                     ; Assembler directive
.include "input.s"                      ; Assembler directive
.include "ouroboros.s"                  ; Assembler directive
.include "config.s"                     ; Assembler directive
.include "ws2812.s"                     ; Assembler directive
.include "dispatch.s"                   ; Assembler directive

; ==============================================================================
; DATA
; ==============================================================================
.include "data.s"                       ; Assembler directive

; ==============================================================================
; VARIABLES
; ==============================================================================
.include "variables.s"                  ; Assembler directive
