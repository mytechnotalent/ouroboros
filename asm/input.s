; ==============================================================================
; Project:       The Ouroboros Engine
; Author:        Kevin Thomas
; E-Mail:        ket189@pitt.edu
; Version:       1.0.0
; Date:          2026-06-26
; Target Device: ATmega328P
; Clock Freq:    8 MHz
; Toolchain:     avr-as, avr-ld, avrdude
; Description:   UART Input Logic
; ==============================================================================

; ==============================================================================
; SUBROUTINE:  handle_uart
; ==============================================================================
; Description: Polls UART for a received byte. If none, returns immediately.
;              On a byte: switches to STATE_INPUT, saves prev_state on
;              first keystroke, flashes white, echoes the character
;              (or handles BS/ENTER), stores up to 32 bytes, and on
;              ENTER runs the full crypto pipeline (key schedule, hash,
;              48-byte blind XOR decryption, branchless MAC verification,
;              bytecode dispatch). After crypto, shows purple (fail) or
;              yellow (success), waits ~5 s, and restores prev_state.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
handle_uart:
  LDS   R16, UCSR0A                     ; Read UART status
  SBRS  R16, RXC0                       ; Byte received?
  RET                                   ; No: return
  LDS   R16, UDR0                       ; Read received byte
  LDS   R17, sys_state                  ; R17 = current mode
  CPI   R17, STATE_INPUT                ; Already in input mode?
  BREQ  .iu_skip_prev                   ; Yes: don't clobber saved state
  STS   prev_state, R17                 ; Save current mode for button-cancel
.iu_skip_prev:
  LDI   R17, STATE_INPUT                ; R17 = STATE_INPUT
  STS   sys_state, R17                  ; Set input mode
  CLR   R24                             ; R24 = 0
  STS   input_timer, R24                ; Reset input timeout low
  STS   input_timer + 1, R24            ; Reset input timeout high
  PUSH  R16                             ; Save received byte
  LDI   R17, 0xFF                       ; Red = 255
  LDI   R18, 0xFF                       ; Green = 255
  LDI   R16, 0xFF                       ; Blue = 255
  RCALL ws2812_fill                     ; Show white on keypress
  POP   R16                             ; Restore received byte
  CPI   R16, 0x0D                       ; Carriage Return?
  BREQ  .iu_enter                       ; Yes: run crypto
  CPI   R16, 0x0A                       ; Line Feed?
  BREQ  .iu_enter                       ; Yes: run crypto
  CPI   R16, 0x08                       ; Backspace?
  BREQ  .iu_bs                          ; Yes: handle backspace
  CPI   R16, 0x7F                       ; Delete?
  BREQ  .iu_bs                          ; Yes: handle backspace
  LDS   R17, uart_idx                   ; R17 = uart_idx
  CPI   R17, INPUT_MAX                  ; Buffer full?
  BRSH  .iu_echo_only                   ; Yes: ignore silently
  LDI   R26, lo8(input_buf)             ; X-ptr low
  LDI   R27, hi8(input_buf)             ; X-ptr high
  ADD   R26, R17                        ; X += uart_idx
  CLR   R18                             ; R18 = 0
  ADC   R27, R18                        ; Add carry
  ST    X, R16                          ; Store character
  INC   R17                             ; Increment index
  STS   uart_idx, R17                   ; Save uart_idx
  RCALL uart_tx_byte                    ; Echo character
  RET                                   ; Return to main loop
.iu_echo_only:
  RET                                   ; Buffer full: ignore character silently
.iu_bs:
  LDS   R17, uart_idx                   ; R17 = uart_idx
  TST   R17                             ; Buffer empty?
  BRNE  .iu_do_bs                       ; No: do backspace
  RET                                   ; Yes: ignore
.iu_do_bs:
  DEC   R17                             ; Decrement index
  STS   uart_idx, R17                   ; Save uart_idx
  LDI   R16, 0x08                       ; R16 = Backspace
  RCALL uart_tx_byte                    ; Send BS
  LDI   R16, ' '                        ; R16 = Space
  RCALL uart_tx_byte                    ; Erase character
  LDI   R16, 0x08                       ; R16 = Backspace
  RCALL uart_tx_byte                    ; Send BS
  RET                                   ; Return to main loop
.iu_enter:
  RCALL tx_crlf                         ; Echo newline
  LDS   R17, uart_idx                   ; R17 = uart_idx
  LDI   R26, lo8(input_buf)             ; X-ptr low
  LDI   R27, hi8(input_buf)             ; X-ptr high
  ADD   R26, R17                        ; X += uart_idx
  CLR   R18                             ; R18 = 0
  ADC   R27, R18                        ; Add carry
  CLR   R16                             ; R16 = 0 (pad byte)
.iu_pad:
  CPI   R17, INPUT_MAX                  ; Done padding?
  BRSH  .iu_crypto                      ; Yes: run crypto
  ST    X+, R16                         ; Store 0 and inc
  INC   R17                             ; Increment count
  RJMP  .iu_pad                         ; Loop
.iu_crypto:
  CLR   R20                             ; R20 = 0 (zero register for crypto)
  CLR   R17                             ; R17 = 0
  STS   uart_idx, R17                   ; Reset uart_idx
  RCALL speck_256_key_schedule          ; Expand key into round_keys
  RCALL davies_meyer_hash_loop          ; Hash IV into CTR nonce
  LDI   R22, 0                          ; Start at cipher index 0
  LDI   R23, 0xFF                       ; saved_index = sentinel (0xFF = not found)
.iu_try:
  RCALL blind_xor_decryption            ; Decrypt entry into result_buf
  RCALL branchless_mac_verification     ; R17 = 0xFF (pass) or 0x00 (fail)
  ; Branchless select: if pass, saved_index = i; else unchanged
  MOV   R0, R22                         ; R0 = i
  AND   R0, R17                         ; R0 = i if pass, 0 if fail
  COM   R17                             ; R17 = 0x00 if pass, 0xFF if fail
  AND   R23, R17                        ; R23 = old if fail, 0 if pass
  OR    R23, R0                         ; R23 = (pass ? i : 0) | (fail ? old : 0)
  INC   R22                             ; Next index
  CPI   R22, CIPHER_ENTRIES             ; All entries tried?
  BRLO  .iu_try                         ; No: loop (constant iterations)
  CPI   R23, 0xFF                       ; Was any entry found?
  BREQ  .iu_all_fail                    ; No: show purple
  ; Winner found — re-decrypt winning entry (hash state still intact)
  MOV   R22, R23                        ; R22 = winning index
  RCALL blind_xor_decryption            ; Re-decrypt winning entry
  RCALL dispatch_program                ; Execute bytecode
  RCALL uart_flush_rx                   ; Flush stale UART bytes
  RCALL tx_prompt                       ; Print prompt
  RCALL clear_input_buf                 ; Zero input buffer
  LDI   R17, 0xFF                       ; Red = 255
  LDI   R18, 0xFF                       ; Green = 255
  LDI   R16, 0x00                       ; Blue = 0
  RCALL ws2812_fill                     ; Show yellow
  LDI   R16, 2                          ; anim_idx = 2 (blue)
  STS   anim_idx, R16                   ; Next animation: blue->wrap->red
  RCALL delay_5s                        ; Wait ~5s showing yellow
  LDS   R16, prev_state                 ; Check mode before input
  CPI   R16, STATE_ANIM                 ; Was it animation?
  BREQ  .iu_force_s                     ; Yes: force advance
  STS   sys_state, R16                  ; Restore button colour
  CLR   R24                             ; R24 = 0
  STS   anim_timer, R24                 ; Reset counter
  STS   anim_timer + 1, R24             ; Reset counter high
  RCALL render_state                    ; Re-draw restored colour
  RET                                   ; Return to main loop
.iu_force_s:
  LDI   R16, STATE_ANIM                 ; Re-assert anim mode
  RCALL force_advance                   ; Advance to next animation colour
  RET                                   ; Return to main loop
.iu_all_fail:
  ; All entries failed — show purple
  RCALL uart_flush_rx                   ; Flush stale UART bytes
  RCALL tx_prompt                       ; Print prompt
  RCALL clear_input_buf                 ; Zero input buffer
  LDI   R17, 0xFF                       ; Red = 255
  LDI   R18, 0x00                       ; Green = 0
  LDI   R16, 0xFF                       ; Blue = 255
  RCALL ws2812_fill                     ; Show purple
  LDI   R16, 1                          ; anim_idx = 1 (green)
  STS   anim_idx, R16                   ; Next animation: green->blue (not red)
  RCALL delay_5s                        ; Wait ~5s showing purple
  LDS   R16, prev_state                 ; Check mode before input
  CPI   R16, STATE_ANIM                 ; Was it animation?
  BREQ  .iu_force_f                     ; Yes: force advance
  STS   sys_state, R16                  ; Restore button colour
  CLR   R24                             ; R24 = 0
  STS   anim_timer, R24                 ; Reset counter
  STS   anim_timer + 1, R24             ; Reset counter high
  RCALL render_state                    ; Re-draw restored colour
  RET                                   ; Return to main loop
.iu_force_f:
  LDI   R16, STATE_ANIM                 ; Re-assert anim mode
  RCALL force_advance                   ; Advance to next animation colour
  RET                                   ; Return to main loop

; ==============================================================================
; SUBROUTINE:  clear_input_buf
; ==============================================================================
; Description: Zeroes the 32-byte input buffer after crypto pipeline
;              completes, preventing stale key material from persisting.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
clear_input_buf:
  LDI   R26, lo8(input_buf)             ; X = input_buf low
  LDI   R27, hi8(input_buf)             ; X = input_buf high
  LDI   R24, INPUT_MAX                  ; 32 bytes
  CLR   R16                             ; R16 = 0
.cib_loop:
  ST    X+, R16                         ; Zero and increment
  DEC   R24                             ; Decrement counter
  BRNE  .cib_loop                       ; Loop 32 times
  RET                                   ; Return to caller
