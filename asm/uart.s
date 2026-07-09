; ==============================================================================
; Project:       The Ouroboros Engine
; Author:        Kevin Thomas
; E-Mail:        ket189@pitt.edu
; Version:       1.0.0
; Date:          2026-06-26
; Target Device: ATmega328P
; Clock Freq:    8 MHz
; Toolchain:     avr-as, avr-ld, avrdude
; Description:   UART Logic
; ==============================================================================

; ==============================================================================
; SUBROUTINE:  uart_init
; ==============================================================================
; Description: Initialize UART0 for 9600 baud.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
uart_init:                              
  CLR    R16                            ; Clear R16
  STS    UCSR0A, R16                    ; Reset UART status A
  STS    UBRR0H, R16                    ; Clear baud rate high byte
  LDI    R16, UBRR_VAL                  ; Load baud rate low byte
  STS    UBRR0L, R16                    ; Set baud rate low byte
  LDI    R16, (1<<RXEN0)|(1<<TXEN0)     ; Set RX/TX enable bits
  STS    UCSR0B, R16                    ; Enable UART RX/TX
  LDI    R16, (1<<UCSZ01)|(1<<UCSZ00)   ; Set 8-bit character size
  STS    UCSR0C, R16                    ; Set frame format
  RET                                   ; Return to caller

; ==============================================================================
; SUBROUTINE:  uart_flush_rx
; ==============================================================================
; Description: Hard-resets the UART receiver by toggling RXEN0. This clears
;              the DOR (Data OverRun) flag and flushes the receive buffer,
;              which is necessary after the 12-second crypto window during
;              which continuous UART overruns degrade the peripheral state.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
uart_flush_rx:                          
  LDS    R18, UCSR0B                    ; Load UART control B
  ANDI   R18, ~(1<<RXEN0)               ; Disable receiver (flushes all state)
  STS    UCSR0B, R18                    ; Write back
  NOP                                   ; Brief settling delay
  ORI    R18, (1<<RXEN0)                ; Re-enable receiver
  STS    UCSR0B, R18                    ; Write back
  RET                                   ; Return to caller

; ==============================================================================
; SUBROUTINE:  uart_tx_byte
; ==============================================================================
; Description: Transmits R16.
; ------------------------------------------------------------------------------
; Parameters:  R16 (Byte)
; Returns:     None
; ==============================================================================
uart_tx_byte:                           
  LDS    R18, UCSR0A                    ; Load UART status
  SBRS   R18, UDRE0                     ; Wait for empty transmit buffer
  RJMP   uart_tx_byte                   ; Loop if buffer full
  STS    UDR0, R16                      ; Write byte to data register
  RET                                   ; Return to caller

; ==============================================================================
; SUBROUTINE:  tx_prompt
; ==============================================================================
; Description: Transmit terminal input prompt.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
tx_prompt:                              
  LDI    R16, '>'                       ; Load '>'
  RCALL  uart_tx_byte                   ; Transmit char
  LDI    R16, ' '                       ; Load space
  RJMP   uart_tx_byte                   ; Tail call transmit

; ==============================================================================
; SUBROUTINE:  tx_crlf
; ==============================================================================
; Description: Transmit terminal formatting crlf.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
tx_crlf:                                
  LDI    R16, 0x0D                      ; Load CR
  RCALL  uart_tx_byte                   ; Transmit CR
  LDI    R16, 0x0A                      ; Load LF
  RJMP   uart_tx_byte                   ; Tail call transmit
