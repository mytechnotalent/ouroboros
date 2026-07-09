; ==============================================================================
; Project:       The Ouroboros Engine
; Author:        Kevin Thomas
; E-Mail:        ket189@pitt.edu
; Version:       1.0.0
; Date:          2026-06-25
; Target Device: ATmega328P
; Clock Freq:    8 MHz
; Toolchain:     avr-as, avr-ld, avrdude
; Description:   Bytecode Dispatcher
; ==============================================================================

; ==============================================================================
; SUBROUTINE:  dispatch_program
; ==============================================================================
; Description: Executes a bytecode program from result_buf. Supports:
;              0x00 END    - halt execution
;              0x01 LED    - fill all 4 LEDs (R, G, B follow)
;              0x03 TX_STR - transmit string (length byte + chars follow)
;              0xAA MAC    - halt execution (integrity marker)
;              Unknown opcodes halt immediately (fail-safe).
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
dispatch_program:
  LDI    R26, lo8(result_buf)           ; Point X to result_buf low
  LDI    R27, hi8(result_buf)           ; Point X to result_buf high
.dispatch_loop:
  LD     R16, X+                        ; Fetch opcode
  CPI    R16, 0x00                      ; END?
  BREQ   .done                          ; Yes: halt
  CPI    R16, 0xAA                      ; MAC marker?
  BREQ   .done                          ; Yes: halt
  CPI    R16, 0x01                      ; LED_FILL?
  BRNE   .check_tx                      ; No: check next opcode
  LD     R17, X+                        ; R
  LD     R18, X+                        ; G
  LD     R16, X+                        ; B
  RCALL  ws2812_fill                    ; Fill LEDs
  RJMP   .dispatch_loop                 ; Continue
.check_tx:
  CPI    R16, 0x03                      ; TX_STR?
  BRNE   .done                          ; Unknown: halt
  LD     R17, X+                        ; Length
.str_loop:
  LD     R16, X+                        ; Character
  RCALL  uart_tx_byte                   ; Transmit
  DEC    R17                            ; Decrement length
  BRNE   .str_loop                      ; Loop until done
  RJMP   .dispatch_loop                 ; Continue
.done:
  RET                                   ; Return to caller
