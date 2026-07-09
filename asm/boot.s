; ==============================================================================
; Project:       The Ouroboros Engine
; Author:        Kevin Thomas
; E-Mail:        ket189@pitt.edu
; Version:       1.0.0
; Date:          2026-06-25
; Target Device: ATmega328P
; Clock Freq:    8 MHz
; Toolchain:     avr-as, avr-ld, avrdude
; Description:   Boot Logic
; ==============================================================================

; ==============================================================================
; SUBROUTINE:  clear_reset_flags
; ==============================================================================
; Description: Wipes the MCU Status Register (MCUSR) clean upon boot.
;              Critically, this clears the Watchdog Reset Flag (WDRF).
;              If a Watchdog timeout caused the last reset, the silicon
;              locks WDRF to 1 and explicitly ignores all software
;              instructions to disable the Watchdog until this flag is
;              forced back to 0. Failing to do this results in an
;              infinite 15ms boot loop.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
clear_reset_flags:
  CLI                                   ; Disable interrupts globally
  WDR                                   ; Pet the dog one last time
  CLR    R16                            ; Clear R16
  OUT    MCUSR, R16                     ; Wipe the Watchdog Reset Flag
  LDI    R16, (1<<4) | (1<<3)           ; Set WDCE and WDE (System Reset)
  STS    WDTCSR, R16                    ; Unlock WDTCSR
  CLR    R16                            ; Clear R16
  STS    WDTCSR, R16                    ; Write 0 to WDTCSR to perm kill WDT
  RET                                   ; Return to caller
