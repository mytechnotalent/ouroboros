; ==============================================================================
; Project:       The Ouroboros Engine
; Author:        Kevin Thomas
; E-Mail:        ket189@pitt.edu
; Version:       1.0.0
; Date:          2026-06-25
; Target Device: ATmega328P
; Clock Freq:    8 MHz
; Toolchain:     avr-as, avr-ld, avrdude
; Description:   Pin Configuration
; ==============================================================================

; ==============================================================================
; SUBROUTINE:  config_pins
; ==============================================================================
; Description: Configures PD3 (button input with pull-up) and PD6
;              (WS2812 data output). Must be called once at boot.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
config_pins:
  SBI    DDRD, PD6                      ; PD6 = output (WS2812 data)
  CBI    PORTD, PD6                     ; Ensure PD6 is LOW
  CBI    DDRD, PD3                      ; PD3 = input (button)
  SBI    PORTD, PD3                     ; PD3 pull-up enabled
  RET                                   ; Return to caller
