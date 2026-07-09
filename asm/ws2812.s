; ==============================================================================
; Project:       The Ouroboros Engine
; Author:        Kevin Thomas
; E-Mail:        ket189@pitt.edu
; Version:       1.0.0
; Date:          2026-06-26
; Target Device: ATmega328P
; Clock Freq:    8 MHz
; Toolchain:     avr-as, avr-ld, avrdude
; Description:   WS2812B Driver (4 LEDs, 8 MHz, bit-banged)
; ==============================================================================

; ==============================================================================
; SUBROUTINE:  send_byte
; ==============================================================================
; Description: Transmits one byte to the WS2812B data line (PD6)
;              using cycle-accurate bit-banging. Uses OUT instead
;              of SBI/CBI for consistent single-cycle I/O timing.
; ------------------------------------------------------------------------------
; Parameters:  R24 (byte to send), R19 (HIGH mask), R20 (LOW mask)
; Returns:     None
; ==============================================================================
send_byte:
  LDI    R23, 8                         ; 8 bits per byte
.bit_loop:
  OUT    PORTD, R19                     ; Drive PD6 HIGH
  SBRS   R24, 7                         ; Skip next if bit 7 is 1
  OUT    PORTD, R20                     ; Drive PD6 LOW (0-bit path)
  LSL    R24                            ; Shift next bit into position
  NOP                                   ; Timing pad
  NOP                                   ; Timing pad
  OUT    PORTD, R20                     ; Drive PD6 LOW (1-bit path)
  DEC    R23                            ; Decrement bit counter
  BRNE   .bit_loop                      ; Loop for 8 bits
  RET                                   ; Return to caller

; ==============================================================================
; SUBROUTINE:  ws2812_fill
; ==============================================================================
; Description: Fills all 4 WS2812B LEDs with a single solid colour.
;              Disables interrupts during the fill for cycle-accurate
;              timing. No explicit reset subroutine needed; the gap
;              between calls naturally exceeds the 80us reset window.
; ------------------------------------------------------------------------------
; Parameters:  R17 (Red), R18 (Green), R16 (Blue)
; Returns:     None
; ==============================================================================
ws2812_fill:
  CLI                                   ; Disable interrupts
  IN     R19, PORTD                     ; Read current PORTD state
  MOV    R20, R19                       ; Copy state for LOW mask
  ORI    R19, (1<<PD6)                  ; Set PD6 in HIGH mask
  ANDI   R20, ~(1<<PD6)                 ; Clear PD6 in LOW mask
  LDI    R25, NUM_LEDS                  ; Load LED count
.fill_loop:
  MOV    R24, R17                       ; R24 = Red
  RCALL  send_byte                      ; Send Red
  MOV    R24, R18                       ; R24 = Green
  RCALL  send_byte                      ; Send Green
  MOV    R24, R16                       ; R24 = Blue
  RCALL  send_byte                      ; Send Blue
  DEC    R25                            ; Decrement LED counter
  BRNE   .fill_loop                     ; Loop for all LEDs
  SEI                                   ; Re-enable interrupts
  RET                                   ; Return to caller

; ==============================================================================
; SUBROUTINE:  render_state
; ==============================================================================
; Description: Reads sys_state and fills LEDs with the corresponding
;              colour. STATE_ANIM uses anim_idx to cycle through
;              red/green/blue. STATE_RED/GREEN/BLUE set solid colours.
;              STATE_INPUT returns immediately.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
render_state:
  LDS   R16, sys_state                  ; Load current mode
  CPI   R16, STATE_ANIM                 ; Animation mode?
  BREQ  .rs_anim                        ; Yes: draw anim sub-colour
  CPI   R16, STATE_RED                  ; Red mode?
  BREQ  .rs_red                         ; Yes: draw red
  CPI   R16, STATE_GREEN                ; Green mode?
  BREQ  .rs_green                       ; Yes: draw green
  CPI   R16, STATE_BLUE                 ; Blue mode?
  BREQ  .rs_blue                        ; Yes: draw blue
  RET                                   ; STATE_INPUT: no change
.rs_anim:
  LDS   R16, anim_idx                   ; Load anim sub-colour
  CPI   R16, 0                          ; Red?
  BREQ  .rs_red                         ; Yes: draw red
  CPI   R16, 1                          ; Green?
  BREQ  .rs_green                       ; Yes: draw green
  RJMP  .rs_blue                        ; Must be blue (2)
.rs_red:
  LDI   R17, 0xFF                       ; Red = 255
  LDI   R18, 0x00                       ; Green = 0
  LDI   R16, 0x00                       ; Blue = 0
  RJMP  ws2812_fill                     ; Tail call
.rs_green:
  LDI   R17, 0x00                       ; Red = 0
  LDI   R18, 0xFF                       ; Green = 255
  LDI   R16, 0x00                       ; Blue = 0
  RJMP  ws2812_fill                     ; Tail call
.rs_blue:
  LDI   R17, 0x00                       ; Red = 0
  LDI   R18, 0x00                       ; Green = 0
  LDI   R16, 0xFF                       ; Blue = 255
  RJMP  ws2812_fill                     ; Tail call
