; ==============================================================================
; Project:       The Ouroboros Engine
; Author:        Kevin Thomas
; E-Mail:        ket189@pitt.edu
; Version:       1.0.0
; Date:          2026-06-26
; Target Device: ATmega328P
; Clock Freq:    8 MHz
; Toolchain:     avr-as, avr-ld, avrdude
; Description:   Delay & Timer Logic
; ==============================================================================

; ==============================================================================
; SUBROUTINE:  delay_and_timers
; ==============================================================================
; Description: Provides a fixed main-loop delay (~5400 cycles), increments
;              the animation timer with threshold-based colour advancement,
;              and increments the input inactivity timer (30-second timeout)
;              when in input mode, restoring prev_state on expiry.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
delay_and_timers:
  LDI   R24, lo8(1349)                  ; Low byte of 1349
  LDI   R25, hi8(1349)                  ; High byte of 1349
.dt_loop:
  SBIW  R24, 1                          ; Decrement 16-bit
  BRNE  .dt_loop                        ; Loop (1349 * 4 cycles ~ 5396)
.dt_check_anim:
  LDS   R24, anim_timer                 ; Load low byte
  LDS   R25, anim_timer + 1             ; Load high byte
  ADIW  R24, 1                          ; Increment 16-bit counter
  STS   anim_timer, R24                 ; Store low byte
  STS   anim_timer + 1, R25             ; Store high byte
  CPI   R25, ANIM_THRESH_H              ; Compare high byte
  BRLO  .dt_done                        ; Below threshold: done
  BRNE  .dt_advance                     ; Above threshold: advance
  CPI   R24, ANIM_THRESH_L              ; Equal high: compare low byte
  BRLO  .dt_done                        ; Below threshold: done
.dt_advance:
  LDS   R16, sys_state                  ; Load current mode
  CPI   R16, STATE_INPUT                ; In input mode?
  BRSH  .dt_input                       ; Yes: check input timeout
  CPI   R16, STATE_ANIM                 ; In animation mode?
  BRNE  .dt_input                       ; No: button colour, check input timeout
  RCALL force_advance                   ; Advance animation
.dt_input:
  LDS   R16, sys_state                  ; Reload mode
  CPI   R16, STATE_INPUT                ; In input mode?
  BRNE  .dt_done                        ; No: done
  LDS   R24, input_timer                ; Load low byte
  LDS   R25, input_timer + 1            ; Load high byte
  ADIW  R24, 1                          ; Increment
  STS   input_timer, R24                ; Store low
  STS   input_timer + 1, R25            ; Store high
  CPI   R24, INPUT_TIMEOUT_L            ; Compare low
  LDI   R16, INPUT_TIMEOUT_H            ; Load high threshold
  CPC   R25, R16                        ; Compare high with borrow
  BRLO  .dt_done                        ; Below threshold: done
  RCALL tx_crlf                         ; Newline
  RCALL tx_prompt                       ; Print "> "
  CLR   R24                             ; R24 = 0
  STS   uart_idx, R24                   ; Reset UART index
  RCALL clear_input_buf                 ; Zero input buffer
  LDS   R16, prev_state                 ; Load saved state
  STS   sys_state, R16                  ; Restore previous mode
  STS   input_timer, R24                ; Reset timer low
  STS   input_timer + 1, R24            ; Reset timer high
  STS   anim_timer, R24                 ; Reset anim counter low
  STS   anim_timer + 1, R24             ; Reset anim counter high
  CPI   R16, STATE_ANIM                 ; Was it animation?
  BREQ  .dt_tmo_force                   ; Yes: force advance
  RCALL render_state                    ; Redraw button colour
  RJMP  .dt_done                        ; Done
.dt_tmo_force:
  LDI   R16, STATE_ANIM                 ; Re-assert anim mode
  RCALL force_advance                   ; Advance and render
.dt_done:
  RET                                   ; Return to main loop

; ==============================================================================
; SUBROUTINE:  force_advance
; ==============================================================================
; Description: Advances the animation by one sub-colour (R->G->B->R),
;              resets the animation timer, and renders the new colour.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
force_advance:
  CLR   R24                             ; R24 = 0
  STS   anim_timer, R24                 ; Reset counter low
  STS   anim_timer + 1, R24             ; Reset counter high
  LDI   R16, STATE_ANIM                 ; R16 = STATE_ANIM
  STS   sys_state, R16                  ; Set animation mode
  LDS   R16, anim_idx                   ; Load anim sub-colour
  INC   R16                             ; Next colour
  CPI   R16, 3                          ; Past blue?
  BRLO  .fa_save                        ; No: save
  CLR   R16                             ; Wrap to red
.fa_save:
  STS   anim_idx, R16                   ; Save anim sub-colour
  RCALL render_state                    ; Update LEDs
  RET                                   ; Return to caller

; ==============================================================================
; SUBROUTINE:  delay_5s
; ==============================================================================
; Description: Blocking software delay of approximately 5 seconds.
;              Clobbers R16, R17, R18.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
delay_5s:
  LDI   R18, 203                        ; Outer: 203 x 256 x 256 x ~3 cycles ~ 5s
.d5_outer:
  LDI   R17, 0                          ; Middle: 256
.d5_mid:
  LDI   R16, 0                          ; Inner: 256
.d5_inner:
  DEC   R16                             ; Decrement inner
  BRNE  .d5_inner                       ; Loop inner
  DEC   R17                             ; Decrement middle
  BRNE  .d5_mid                         ; Loop middle
  DEC   R18                             ; Decrement outer
  BRNE  .d5_outer                       ; Loop outer
  RET                                   ; Return to caller
