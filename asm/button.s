; ==============================================================================
; Project:       The Ouroboros Engine
; Author:        Kevin Thomas
; E-Mail:        ket189@pitt.edu
; Version:       1.0.0
; Date:          2026-06-26
; Target Device: ATmega328P
; Clock Freq:    8 MHz
; Toolchain:     avr-as, avr-ld, avrdude
; Description:   Button Logic
; ==============================================================================

; ==============================================================================
; SUBROUTINE:  handle_button
; ==============================================================================
; Description: Polls the button (PD3). If pressed, debounces, waits for
;              release, and cycles the system mode (ANIM->RED->GREEN->
;              BLUE->ANIM). If currently in input mode, cancels input
;              and restores prev_state. If no button press, falls
;              through to handle_uart for UART polling.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
handle_button:
  SBIC  PIND, PD3                       ; Button pressed (PD3 low)?
  RJMP  handle_uart                     ; No: check UART
  LDI   R16, 0                          ; Inner counter (256)
  LDI   R17, 0                          ; Outer counter (256)
.btn_debounce:
  DEC   R16                             ; Decrement inner
  BRNE  .btn_debounce                   ; Loop inner 256x
  DEC   R17                             ; Decrement outer
  BRNE  .btn_debounce                   ; Loop outer 256x (~24ms total)
  SBIC  PIND, PD3                       ; Still pressed after debounce?
  RJMP  handle_uart                     ; No: discard as bounce
.btn_wait_rel:
  SBIS  PIND, PD3                       ; Released yet?
  RJMP  .btn_wait_rel                   ; No: keep waiting
  LDS   R16, sys_state                  ; Load current mode
  CPI   R16, STATE_INPUT                ; In input mode?
  BREQ  .btn_done                       ; Yes: ignore (no cancel)
  INC   R16                             ; Next mode
  CPI   R16, STATE_INPUT                ; Past blue (wrap to anim)?
  BRLO  .btn_set                        ; No: set mode
  CLR   R16                             ; Wrap to animation
  STS   anim_idx, R16                   ; Start anim from red
.btn_set:
  STS   sys_state, R16                  ; Save new mode
  RCALL render_state                    ; Show colour
  RET                                   ; Return to main loop
.btn_done:
  RET                                   ; Ignore button press
