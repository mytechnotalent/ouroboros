; ==============================================================================
; Project:       The Ouroboros Engine
; Author:        Kevin Thomas
; E-Mail:        ket189@pitt.edu
; Version:       1.0.0
; Date:          2026-06-26
; Target Device: ATmega328P
; Clock Freq:    8 MHz
; Toolchain:     avr-as, avr-ld, avrdude
; Description:   Register Aliases & Constants
; ==============================================================================

; ==============================================================================
; SYMBOLIC REGISTER AND I/O DEFINITIONS
; ==============================================================================
.equ UCSR0A,          0xC0              ; USART Control & Status Register A
.equ UCSR0B,          0xC1              ; USART Control & Status Register B
.equ UCSR0C,          0xC2              ; USART Control & Status Register C
.equ UBRR0L,          0xC4              ; USART Baud Rate Register Low
.equ UBRR0H,          0xC5              ; USART Baud Rate Register High
.equ UDR0,            0xC6              ; USART Data Register
.equ RXEN0,           4                 ; Receiver Enable bit
.equ TXEN0,           3                 ; Transmitter Enable bit
.equ UDRE0,           5                 ; Data Register Empty bit
.equ RXC0,            7                 ; Receive Complete bit
.equ UCSZ00,          1                 ; Character Size bit 0
.equ UCSZ01,          2                 ; Character Size bit 1
.equ SPH,             0x3E              ; Stack Pointer High
.equ SPL,             0x3D              ; Stack Pointer Low
.equ RAMEND,          0x08FF            ; Last SRAM address (ATmega328P)
.equ PORTB,           0x05              ; Port B Data Register
.equ DDRB,            0x04              ; Port B Data Direction Register
.equ PIND,            0x09              ; Port D Input Pins Address
.equ PORTD,           0x0B              ; Port D Data Register
.equ DDRD,            0x0A              ; Port D Data Direction Register
.equ PB5,             5                 ; Port B Pin 5
.equ PD2,             2                 ; Port D Pin 2
.equ PD3,             3                 ; Port D Pin 3 (Button)
.equ PD4,             4                 ; Port D Pin 4
.equ PD6,             6                 ; Port D Pin 6
.equ TCCR1B,          0x81              ; Timer/Counter1 Control Register B
.equ TCNT1L,          0x84              ; Timer/Counter1 Low Byte
.equ TCNT1H,          0x85              ; Timer/Counter1 High Byte
.equ CS10,            0                 ; Clock Select 0 bit
.equ CS12,            2                 ; Clock Select 2 bit
.equ MCUSR,           0x34              ; MCU Status Register
.equ WDTCSR,          0x60              ; Watchdog Timer Control Register
.equ SPECK_ROUNDS,    34                ; Speck128/256 round count
.equ KEY_BYTES,       32                ; 256-bit key = 32 bytes
.equ BLOCK_BYTES,     16                ; 128-bit block = 16 bytes
.equ INPUT_MAX,       32                ; Max UART input bytes (zero-padded)
.equ UBRR_VAL,        51                ; 8MHz / (16*9600) - 1 = 51
.equ NUM_LEDS,        4                 ; Number of WS2812 LEDs
.equ TIMER_THRESH_H,  0x98              ; Timer threshold high byte (~5s at /1024)
.equ TIMER_THRESH_L,  0x96              ; Timer threshold low byte (~5s at /1024)
.equ ANIM_THRESH_H,   0x1C              ; Software counter high byte (~5s at 8MHz)
.equ ANIM_THRESH_L,   0xD4              ; Software counter low byte
.equ STATE_ANIM,      0                 ; Boot animation cycling
.equ STATE_RED,       1                 ; Solid red (button 1x or crypto fail)
.equ STATE_GREEN,     2                 ; Solid green (button 2x or crypto success)
.equ STATE_BLUE,      3                 ; Solid blue (button 3x)
.equ STATE_INPUT,     4                 ; User typing mode
.equ INPUT_TIMEOUT_L, 0xF8              ; Input timeout low byte (~30s at ~1476 iter/s)
.equ INPUT_TIMEOUT_H, 0xAC              ; Input timeout high byte (~30s)
.equ CIPHER_ENTRIES,  2                 ; Number of entries in table_ciphers
