; ==============================================================================
; Project:       The Ouroboros Engine
; Author:        Kevin Thomas
; E-Mail:        ket189@pitt.edu
; Version:       1.0.0
; Date:          2026-06-26
; Target Device: ATmega328P
; Clock Freq:    8 MHz
; Toolchain:     avr-as, avr-ld, avrdude
; Description:   Ouroboros Core Logic
; ==============================================================================

; ==============================================================================
; SUBROUTINE:  speck_256_key_schedule
; ==============================================================================
; Description: Computes 34 Speck128/256 round keys from the 32-byte
;              key using 64-bit rotations and circular buffers.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
speck_256_key_schedule:
  LDI    R26, lo8(input_buf)            ; Point X to input_buf low
  LDI    R27, hi8(input_buf)            ; Point X to input_buf high
  LDI    R28, lo8(round_keys)           ; Point Y to round_keys low
  LDI    R29, hi8(round_keys)           ; Point Y to round_keys high
  LDI    R16, 8                         ; Set counter to 8
.ks_k0:
  LD     R17, X+                        ; Fetch key byte
  ST     Y+, R17                        ; Store to round_keys
  DEC    R16                            ; Decrement counter
  BRNE   .ks_k0                         ; Loop 8 times
  LDI    R28, lo8(l_buf)                ; Point Y to l_buf low
  LDI    R29, hi8(l_buf)                ; Point Y to l_buf high
  LDI    R16, 24                        ; Set counter to 24
.ks_l:
  LD     R17, X+                        ; Fetch key byte
  ST     Y+, R17                        ; Store to l_buf
  DEC    R16                            ; Decrement counter
  BRNE   .ks_l                          ; Loop 24 times
  LDI    R26, lo8(round_keys)           ; Point X to round_keys low
  LDI    R27, hi8(round_keys)           ; Point X to round_keys high
  LD     R8, X+                         ; Load k_0 to R8
  LD     R9, X+                         ; Load k_0 to R9
  LD     R10, X+                        ; Load k_0 to R10
  LD     R11, X+                        ; Load k_0 to R11
  LD     R12, X+                        ; Load k_0 to R12
  LD     R13, X+                        ; Load k_0 to R13
  LD     R14, X+                        ; Load k_0 to R14
  LD     R15, X+                        ; Load k_0 to R15
  CLR    R24                            ; Clear round counter
.ks_loop:
  MOV    R16, R24                       ; Copy round counter
.ks_mod3_rd_loop:
  CPI    R16, 3                         ; Check if >= 3
  BRLO   .ks_mod3_rd_done               ; Exit if less than 3
  SUBI   R16, 3                         ; Subtract 3
  RJMP   .ks_mod3_rd_loop               ; Repeat
.ks_mod3_rd_done:
  LSL    R16                            ; Multiply by 2
  LSL    R16                            ; Multiply by 4
  LSL    R16                            ; Multiply by 8 (block size)
  LDI    R28, lo8(l_buf)                ; Point Y to l_buf low
  LDI    R29, hi8(l_buf)                ; Point Y to l_buf high
  ADD    R28, R16                       ; Add offset to Y low
  ADC    R29, R20                       ; Add carry to Y high
  LD     R0, Y+                         ; Load l_buf block
  LD     R1, Y+                         ; Load l_buf block
  LD     R2, Y+                         ; Load l_buf block
  LD     R3, Y+                         ; Load l_buf block
  LD     R4, Y+                         ; Load l_buf block
  LD     R5, Y+                         ; Load l_buf block
  LD     R6, Y+                         ; Load l_buf block
  LD     R7, Y+                         ; Load l_buf block
  PUSH   R16                            ; Save offset for write phase
  RCALL  speck_round_half1              ; Execute ARX half 1
  EOR    R0, R24                        ; XOR with round counter
  POP    R16                            ; Restore offset for write phase
  LDI    R28, lo8(l_buf)                ; Point Y to l_buf low
  LDI    R29, hi8(l_buf)                ; Point Y to l_buf high
  ADD    R28, R16                       ; Add offset to Y low
  ADC    R29, R20                       ; Add carry to Y high
  ST     Y+, R0                         ; Store updated l_buf block
  ST     Y+, R1                         ; Store updated l_buf block
  ST     Y+, R2                         ; Store updated l_buf block
  ST     Y+, R3                         ; Store updated l_buf block
  ST     Y+, R4                         ; Store updated l_buf block
  ST     Y+, R5                         ; Store updated l_buf block
  ST     Y+, R6                         ; Store updated l_buf block
  ST     Y+, R7                         ; Store updated l_buf block
  RCALL  speck_round_half2              ; Execute ARX half 2
  MOV    R16, R24                       ; Copy round counter
  INC    R16                            ; Increment for next k
  CLR    R17                            ; Clear high byte offset
  LSL    R16                            ; Multiply by 2
  ROL    R17                            ; Rotate carry to high byte
  LSL    R16                            ; Multiply by 4
  ROL    R17                            ; Rotate carry to high byte
  LSL    R16                            ; Multiply by 8 (block size)
  ROL    R17                            ; Rotate carry to high byte
  LDI    R28, lo8(round_keys)           ; Point Y to round_keys low
  LDI    R29, hi8(round_keys)           ; Point Y to round_keys high
  ADD    R28, R16                       ; Add offset to Y low
  ADC    R29, R17                       ; Add carry to Y high
  ST     Y+, R8                         ; Store round key block
  ST     Y+, R9                         ; Store round key block
  ST     Y+, R10                        ; Store round key block
  ST     Y+, R11                        ; Store round key block
  ST     Y+, R12                        ; Store round key block
  ST     Y+, R13                        ; Store round key block
  ST     Y+, R14                        ; Store round key block
  ST     Y+, R15                        ; Store round key block
  INC    R24                            ; Increment round counter
  CPI    R24, 33                        ; Check if 33 rounds complete
  BREQ   .ks_loop_exit                  ; Exit if done
  RJMP   .ks_loop                       ; Loop back (long range)
.ks_loop_exit:
  RET                                   ; Return to caller

; ==============================================================================
; SUBROUTINE:  speck_round_half1
; ==============================================================================
; Description: First half of the Speck ARX round function.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
speck_round_half1:
  MOV    R16, R0                        ; Copy R0 to temp
  MOV    R0, R1                         ; Shift state
  MOV    R1, R2                         ; Shift state
  MOV    R2, R3                         ; Shift state
  MOV    R3, R4                         ; Shift state
  MOV    R4, R5                         ; Shift state
  MOV    R5, R6                         ; Shift state
  MOV    R6, R7                         ; Shift state
  MOV    R7, R16                        ; Shift state wrap around
  ADD    R0, R8                         ; Add with round key
  ADC    R1, R9                         ; Add with carry
  ADC    R2, R10                        ; Add with carry
  ADC    R3, R11                        ; Add with carry
  ADC    R4, R12                        ; Add with carry
  ADC    R5, R13                        ; Add with carry
  ADC    R6, R14                        ; Add with carry
  ADC    R7, R15                        ; Add with carry
  RET                                   ; Return to caller

; ==============================================================================
; SUBROUTINE:  speck_round_half2
; ==============================================================================
; Description: Second half of the Speck ARX round function.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
speck_round_half2:
  LSL    R8                             ; First rotation: bit 7 to carry
  ROL    R9                             ; Rotate through regs
  ROL    R10                            ; Rotate through regs
  ROL    R11                            ; Rotate through regs
  ROL    R12                            ; Rotate through regs
  ROL    R13                            ; Rotate through regs
  ROL    R14                            ; Rotate through regs
  ROL    R15                            ; Rotate through regs
  ADC    R8, R20                        ; Carry back to bit 0
  LSL    R8                             ; Second rotation
  ROL    R9                             ; Rotate through regs
  ROL    R10                            ; Rotate through regs
  ROL    R11                            ; Rotate through regs
  ROL    R12                            ; Rotate through regs
  ROL    R13                            ; Rotate through regs
  ROL    R14                            ; Rotate through regs
  ROL    R15                            ; Rotate through regs
  ADC    R8, R20                        ; Carry back to bit 0
  LSL    R8                             ; Third rotation
  ROL    R9                             ; Rotate through regs
  ROL    R10                            ; Rotate through regs
  ROL    R11                            ; Rotate through regs
  ROL    R12                            ; Rotate through regs
  ROL    R13                            ; Rotate through regs
  ROL    R14                            ; Rotate through regs
  ROL    R15                            ; Rotate through regs
  ADC    R8, R20                        ; Carry back to bit 0
  EOR    R8, R0                         ; XOR state
  EOR    R9, R1                         ; XOR state
  EOR    R10, R2                        ; XOR state
  EOR    R11, R3                        ; XOR state
  EOR    R12, R4                        ; XOR state
  EOR    R13, R5                        ; XOR state
  EOR    R14, R6                        ; XOR state
  EOR    R15, R7                        ; XOR state
  RET                                   ; Return to caller

; ==============================================================================
; SUBROUTINE:  encrypt_block
; ==============================================================================
; Description: Encrypts a 128-bit block using Speck-256 in constant time.
; ------------------------------------------------------------------------------
; Parameters:  X (R26:R27) Pointer to 16-byte block
; Returns:     None (Mutates block in place)
; ==============================================================================
encrypt_block:
  LD     R0, X+                         ; Load block byte
  LD     R1, X+                         ; Load block byte
  LD     R2, X+                         ; Load block byte
  LD     R3, X+                         ; Load block byte
  LD     R4, X+                         ; Load block byte
  LD     R5, X+                         ; Load block byte
  LD     R6, X+                         ; Load block byte
  LD     R7, X+                         ; Load block byte
  LD     R8, X+                         ; Load block byte
  LD     R9, X+                         ; Load block byte
  LD     R10, X+                        ; Load block byte
  LD     R11, X+                        ; Load block byte
  LD     R12, X+                        ; Load block byte
  LD     R13, X+                        ; Load block byte
  LD     R14, X+                        ; Load block byte
  LD     R15, X+                        ; Load block byte
  LDI    R28, lo8(round_keys)           ; Point Y to round_keys low
  LDI    R29, hi8(round_keys)           ; Point Y to round_keys high
  CLR    R24                            ; Clear round counter
  LDI    R25, SPECK_ROUNDS              ; Load total rounds
.enc_round:
  RCALL  hardware_jitter_and_exe        ; Mitigate power analysis
  RCALL  speck_round_half1              ; Execute ARX half 1
  LD     R16, Y+                        ; Load key byte
  EOR    R0, R16                        ; XOR key
  LD     R16, Y+                        ; Load key byte
  EOR    R1, R16                        ; XOR key
  LD     R16, Y+                        ; Load key byte
  EOR    R2, R16                        ; XOR key
  LD     R16, Y+                        ; Load key byte
  EOR    R3, R16                        ; XOR key
  LD     R16, Y+                        ; Load key byte
  EOR    R4, R16                        ; XOR key
  LD     R16, Y+                        ; Load key byte
  EOR    R5, R16                        ; XOR key
  LD     R16, Y+                        ; Load key byte
  EOR    R6, R16                        ; XOR key
  LD     R16, Y+                        ; Load key byte
  EOR    R7, R16                        ; XOR key
  RCALL  speck_round_half2              ; Execute ARX half 2
  INC    R24                            ; Increment round counter
  CP     R24, R25                       ; Check if all rounds complete
  BRNE   .enc_round                     ; Loop if not complete
  SBIW   R26, 16                        ; Rewind X pointer
  ST     X+, R0                         ; Store encrypted block byte
  ST     X+, R1                         ; Store encrypted block byte
  ST     X+, R2                         ; Store encrypted block byte
  ST     X+, R3                         ; Store encrypted block byte
  ST     X+, R4                         ; Store encrypted block byte
  ST     X+, R5                         ; Store encrypted block byte
  ST     X+, R6                         ; Store encrypted block byte
  ST     X+, R7                         ; Store encrypted block byte
  ST     X+, R8                         ; Store encrypted block byte
  ST     X+, R9                         ; Store encrypted block byte
  ST     X+, R10                        ; Store encrypted block byte
  ST     X+, R11                        ; Store encrypted block byte
  ST     X+, R12                        ; Store encrypted block byte
  ST     X+, R13                        ; Store encrypted block byte
  ST     X+, R14                        ; Store encrypted block byte
  ST     X+, R15                        ; Store encrypted block byte
  RET                                   ; Return to caller

; ==============================================================================
; SUBROUTINE:  davies_meyer_hash_loop
; ==============================================================================
; Description: Iterates the Davies-Meyer hash construction 24,576
;              times to mitigate offline dictionary attacks.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
davies_meyer_hash_loop:
  LDI    R30, lo8(iv_const)             ; Point Z to IV low
  LDI    R31, hi8(iv_const)             ; Point Z to IV high
  LDI    R26, lo8(hash_buf)             ; Point X to hash_buf low
  LDI    R27, hi8(hash_buf)             ; Point X to hash_buf high
  LDI    R16, 16                        ; Set counter to 16
.hash_copy:
  LPM    R17, Z+                        ; Load IV byte from Flash
  ST     X+, R17                        ; Store IV to hash_buf
  DEC    R16                            ; Decrement counter
  BRNE   .hash_copy                     ; Loop until IV copied
  LDI    R30, lo8(24576)                ; Set iteration counter low
  LDI    R31, hi8(24576)                ; Set iteration counter high
.hash_stretch:
  RCALL  hardware_jitter_and_exe        ; Add jitter delay
  LDI    R26, lo8(hash_buf)             ; Reset X to hash_buf low
  LDI    R27, hi8(hash_buf)             ; Reset X to hash_buf high
  RCALL  encrypt_block                  ; Encrypt buffer in place
  SBIW   R30, 1                         ; Decrement 16-bit counter
  BRNE   .hash_stretch                  ; Loop until 24,576 iterations
  LDI    R30, lo8(iv_const)             ; Reset Z to IV low
  LDI    R31, hi8(iv_const)             ; Reset Z to IV high
  LDI    R26, lo8(hash_buf)             ; Reset X to hash_buf low
  LDI    R27, hi8(hash_buf)             ; Reset X to hash_buf high
  LDI    R16, 16                        ; Set counter to 16
.hash_xor:
  LPM    R17, Z+                        ; Load IV byte
  LD     R18, X                         ; Load hash byte
  EOR    R18, R17                       ; Feed-forward XOR
  ST     X+, R18                        ; Store finalized hash byte
  DEC    R16                            ; Decrement counter
  BRNE   .hash_xor                      ; Loop 16 times
  RET                                   ; Return to caller

; ==============================================================================
; SUBROUTINE:  keystream_generation
; ==============================================================================
; Description: Constructs the CTR block from the hash nonce.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
keystream_generation:
  LDI    R26, lo8(hash_buf)             ; Point X to hash_buf low
  LDI    R27, hi8(hash_buf)             ; Point X to hash_buf high
  LDI    R28, lo8(ctr_buf)              ; Point Y to ctr_buf low
  LDI    R29, hi8(ctr_buf)              ; Point Y to ctr_buf high
  LDI    R16, 8                         ; Set counter to 8
.ctr_nonce:
  LD     R17, X+                        ; Load nonce byte
  ST     Y+, R17                        ; Store to ctr_buf
  DEC    R16                            ; Decrement counter
  BRNE   .ctr_nonce                     ; Loop 8 times
  ST     Y+, R24                        ; Store block counter
  LDI    R16, 7                         ; Set padding counter to 7
.ctr_zero:
  ST     Y+, R20                        ; Store zero padding
  DEC    R16                            ; Decrement counter
  BRNE   .ctr_zero                      ; Loop 7 times
  LDI    R26, lo8(ctr_buf)              ; Reset X to ctr_buf low
  LDI    R27, hi8(ctr_buf)              ; Reset X to ctr_buf high
  RCALL  encrypt_block                  ; Encrypt CTR block
  RET                                   ; Return to caller

; ==============================================================================
; SUBROUTINE:  blind_xor_decryption
; ==============================================================================
; Description: Decrypts 48 bytes of ciphertext in 3 CTR blocks.
; ------------------------------------------------------------------------------
; Parameters:  R22 (Table Index)
; Returns:     None
; ==============================================================================
blind_xor_decryption:
  LDI    R30, lo8(table_ciphers)        ; Point Z to cipher table low
  LDI    R31, hi8(table_ciphers)        ; Point Z to cipher table high
  MOV    R16, R22                       ; Copy index
  LSL    R16                            ; Multiply by 2
  LSL    R16                            ; Multiply by 4
  LSL    R16                            ; Multiply by 8
  LSL    R16                            ; Multiply by 16
  MOV    R17, R16                       ; Save value (index * 16)
  LSL    R16                            ; Multiply by 32
  ADD    R16, R17                       ; Index * 48 (block offset)
  ADD    R30, R16                       ; Add offset to Z low
  CLR    R16                            ; Clear zero register
  ADC    R31, R16                       ; Add carry to Z high
  LDI    R28, lo8(result_buf)           ; Point Y to result_buf low
  LDI    R29, hi8(result_buf)           ; Point Y to result_buf high
  CLR    R24                            ; Clear block counter
.dp_loop:
  PUSH   R24                            ; Save block counter
  PUSH   R30                            ; Save Z pointer low
  PUSH   R31                            ; Save Z pointer high
  PUSH   R28                            ; Save Y pointer low
  PUSH   R29                            ; Save Y pointer high
  RCALL  keystream_generation           ; Generate keystream block
  POP    R29                            ; Restore Y pointer high
  POP    R28                            ; Restore Y pointer low
  POP    R31                            ; Restore Z pointer high
  POP    R30                            ; Restore Z pointer low
  POP    R24                            ; Restore block counter
  LDI    R26, lo8(ctr_buf)              ; Point X to ctr_buf low
  LDI    R27, hi8(ctr_buf)              ; Point X to ctr_buf high
  LDI    R16, 16                        ; Set XOR counter
.dp_xor:
  LPM    R17, Z+                        ; Load ciphertext byte
  LD     R18, X+                        ; Load keystream byte
  EOR    R17, R18                       ; XOR to decrypt
  ST     Y+, R17                        ; Store plaintext byte
  DEC    R16                            ; Decrement counter
  BRNE   .dp_xor                        ; Loop 16 times
  INC    R24                            ; Increment block counter
  CPI    R24, 3                         ; Check if 3 blocks complete
  BRNE   .dp_loop                       ; Loop if not complete
  RET                                   ; Return to caller

; ==============================================================================
; SUBROUTINE:  branchless_mac_verification
; ==============================================================================
; Description: Constant-time mask generation to prevent ciphertext
;              malleability.
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
branchless_mac_verification:
  LDI    R26, lo8(result_buf)           ; Point X to result_buf low
  LDI    R27, hi8(result_buf)           ; Point X to result_buf high
  ADIW   R26, 16                        ; Skip first 16 bytes
  LDI    R18, 32                        ; Set MAC check length
  CLR    R17                            ; Clear error accumulator
.mac_check_loop:
  LD     R16, X+                        ; Load byte
  SUBI   R16, 0xAA                      ; Subtract expected padding
  OR     R17, R16                       ; Accumulate any differences
  DEC    R18                            ; Decrement length counter
  BRNE   .mac_check_loop                ; Loop 32 times
  NEG    R17                            ; 2s complement of accumulator
  SBC    R17, R17                       ; Subtract with carry to create mask
  COM    R17                            ; Invert mask (0xFF if valid, 0x00 if invalid)
  LDI    R26, lo8(result_buf)           ; Reset X pointer
  LDI    R27, hi8(result_buf)           ; Reset X pointer
  LDI    R18, 48                        ; Set mask length
.mac_mask_loop:
  LD     R19, X                         ; Load byte
  AND    R19, R17                       ; Apply mask
  ST     X+, R19                        ; Store byte back
  DEC    R18                            ; Decrement counter
  BRNE   .mac_mask_loop                 ; Loop 48 times
  RET                                   ; Return to caller

; ==============================================================================
; SUBROUTINE:  hardware_jitter_and_exe
; ==============================================================================
; Description: Introduces random clock jitter using TCNT0 to defeat
;              Differential Power Analysis (DPA).
; ------------------------------------------------------------------------------
; Parameters:  None
; Returns:     None
; ==============================================================================
hardware_jitter_and_exe:
  IN     R16, 0x26                      ; Read TCNT0
  ANDI   R16, 0x07                      ; Isolate bottom 3 bits (0-7 cycles)
.jitter_loop:
  DEC    R16                            ; Decrement
  BRPL   .jitter_loop                   ; Loop if still positive (signed)
  RET                                   ; Return to caller
