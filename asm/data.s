; ==============================================================================
; Project:       The Ouroboros Engine
; Author:        Kevin Thomas
; E-Mail:        ket189@pitt.edu
; Version:       1.0.0
; Date:          2026-06-26
; Target Device: ATmega328P
; Clock Freq:    8 MHz
; Toolchain:     avr-as, avr-ld, avrdude
; Description:   Data Section (Flash Memory Payloads)
; ==============================================================================

; ==============================================================================
; Public IV (SHA-256 initialization constants, first 16 bytes)
; ==============================================================================
iv_const:
  .byte 0x6A, 0x09, 0xE6, 0x67          ; Data chunk 0
  .byte 0xBB, 0x67, 0xAE, 0x85          ; Data chunk 1
  .byte 0x3C, 0x6E, 0xF3, 0x72          ; Data chunk 2
  .byte 0xA5, 0x4F, 0xF5, 0x3A          ; Data chunk 3

; ==============================================================================
; TABLE: Bytecode Ciphers
; ==============================================================================
; Each 48-byte entry: 16B encrypted bytecode (LED_FILL purple + TX_STR + END)
; + 32B encrypted 0xAA MAC. Block 1-2 MACs unchanged from original.
table_ciphers:
  .byte 0xB3, 0x51, 0xB6, 0x05          ; hello->world chunk 0
  .byte 0x78, 0xD4, 0x91, 0xFE          ; hello->world chunk 1
  .byte 0xC0, 0x87, 0x82, 0xBD          ; hello->world chunk 2
  .byte 0xDA, 0x87, 0x6E, 0xF9          ; hello->world chunk 3
  .byte 0x09, 0x23, 0xE5, 0xA5          ; hello->world chunk 4
  .byte 0x69, 0x9F, 0x34, 0x4B          ; hello->world chunk 5
  .byte 0xDD, 0x24, 0xD3, 0x4A          ; hello->world chunk 6
  .byte 0x35, 0x96, 0x47, 0x7F          ; hello->world chunk 7
  .byte 0xB3, 0x13, 0xFC, 0x6C          ; hello->world chunk 8
  .byte 0x7B, 0x95, 0xAE, 0x25          ; hello->world chunk 9
  .byte 0xD1, 0x1C, 0xA5, 0x0A          ; hello->world chunk 10
  .byte 0xD7, 0xE1, 0x65, 0x3A          ; hello->world chunk 11
  .byte 0x5A, 0x9C, 0xB0, 0xD9          ; foo->bar chunk 0
  .byte 0xDA, 0xB7, 0x6D, 0x26          ; foo->bar chunk 1
  .byte 0xB7, 0x48, 0x7B, 0xBC          ; foo->bar chunk 2
  .byte 0x26, 0xCA, 0x34, 0x3C          ; foo->bar chunk 3
  .byte 0x14, 0x72, 0xDE, 0xF4          ; foo->bar chunk 4
  .byte 0xE5, 0xEE, 0x73, 0xC2          ; foo->bar chunk 5
  .byte 0x53, 0xB2, 0xAE, 0x1B          ; foo->bar chunk 6
  .byte 0xA8, 0xC0, 0xAF, 0xE7          ; foo->bar chunk 7
  .byte 0xDE, 0x20, 0x31, 0x93          ; foo->bar chunk 8
  .byte 0x7E, 0xFB, 0xEF, 0x80          ; foo->bar chunk 9
  .byte 0xFD, 0x82, 0xF8, 0x7B          ; foo->bar chunk 10
  .byte 0xF8, 0xDA, 0x59, 0x51          ; foo->bar chunk 11
