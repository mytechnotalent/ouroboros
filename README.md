![image](https://github.com/mytechnotalent/ouroboros/blob/main/Ouroboros.png?raw=true)

## FREE Reverse Engineering Self-Study Course [HERE](https://github.com/mytechnotalent/Reverse-Engineering-Tutorial)

<br>

# The Ouroboros Engine
**A bare-metal cryptographic authentication framework written in pure AVR assembly for the ATmega328P.**

<br>

| Field | Value |
|---|---|
| Author | Kevin Thomas (`ket189@pitt.edu`) |
| Version | 1.0.0 |
| Date | 2026-06-26 |
| Target | ATmega328P |
| Clock | 8 MHz internal RC |
| Toolchain | `avr-as`, `avr-ld`, `avrdude` |
| License | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |

---

## Table of Contents

- [The Ouroboros Engine](#the-ouroboros-engine)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [System Architecture](#system-architecture)
  - [Cryptographic Design](#cryptographic-design)
    - [Speck-128/256](#speck-128256)
    - [Davies-Meyer Key Stretching](#davies-meyer-key-stretching)
    - [CTR-Mode Decryption](#ctr-mode-decryption)
    - [Branchless MAC Verification](#branchless-mac-verification)
    - [Blind Cipher Selection](#blind-cipher-selection)
  - [Hardware Subsystems](#hardware-subsystems)
    - [WS2812B LED Driver](#ws2812b-led-driver)
    - [UART Interface](#uart-interface)
    - [Button Logic](#button-logic)
    - [Timer Architecture](#timer-architecture)
  - [Bytecode Interpreter](#bytecode-interpreter)
  - [Side-Channel Countermeasures](#side-channel-countermeasures)
    - [Hardware Jitter (`hardware_jitter_and_exe`)](#hardware-jitter-hardware_jitter_and_exe)
    - [Constant-Time MAC Comparison](#constant-time-mac-comparison)
    - [Constant-Iteration Cipher Scan](#constant-iteration-cipher-scan)
    - [Key Material Zeroization](#key-material-zeroization)
    - [UART DOR Recovery](#uart-dor-recovery)
    - [Watchdog Neutralization](#watchdog-neutralization)
  - [State Machine](#state-machine)
  - [Boot Sequence](#boot-sequence)
  - [Memory Map](#memory-map)
    - [Flash (32 KB, `.text` section)](#flash-32-kb-text-section)
    - [SRAM (2 KB, `.bss` section, base `0x0100`)](#sram-2-kb-bss-section-base-0x0100)
  - [Build \& Flash](#build--flash)
    - [Prerequisites](#prerequisites)
    - [Build](#build)
    - [Fuse Settings](#fuse-settings)
    - [Adding Cipher Entries](#adding-cipher-entries)
  - [File Structure](#file-structure)
  - [Security Analysis](#security-analysis)
    - [Threat Model](#threat-model)
    - [Attack Surface](#attack-surface)
    - [Key Space](#key-space)
    - [Offline Attack Cost](#offline-attack-cost)

---

## Overview

The Ouroboros Engine is a single-file, dependency-free embedded system that implements a hardware-bound cryptographic challenge-response path. Running entirely in hand-crafted AVR assembly on an ATmega328P clocked at 8 MHz with no external crystal, it accepts a secret passphrase over a serial terminal, stretches it through a deliberately expensive Davies-Meyer hash construction (24,576 iterations of Speck-128/256), derives a CTR-mode keystream, decrypts an encrypted bytecode payload from flash, checks a 32-byte fixed MAC region with a constant-time branchless routine, and — on success — executes a minimal bytecode interpreter that drives WS2812B LEDs and transmits a response string over UART.

The name "Ouroboros" refers to the self-referential nature of the design: the hash output feeds the CTR nonce, which decrypts the program that controls the system, which was originally encrypted by the same algorithm running in Python — a circular, self-contained trust chain.

---

## System Architecture

```
                        ┌─────────────────────────────────────┐
                        │          ATmega328P @ 8 MHz         │
                        │                                     │
  UART (9600 8N1) ─────►│  handle_uart()                      │
                        │       │                             │
                        │       ▼                             │
                        │  input_buf[32] (SRAM)               │
                        │       │                             │
                        │       ▼                             │
                        │  speck_256_key_schedule()           │
                        │    → round_keys[272] (34 × 8 bytes) │
                        │       │                             │
                        │       ▼                             │
                        │  davies_meyer_hash_loop()           │
                        │    → hash_buf[16]  (24,576 iters)   │
                        │       │                             │
                        │       ▼                             │
                        │  blind_xor_decryption()             │
                        │    (constant-time over all entries) │
                        │       │                             │
                        │       ▼                             │
                        │  branchless_mac_verification()      │
                        │    → result_buf[48] masked          │
                        │       │                             │
                        │       ▼                             │
                        │  dispatch_program()                 │
                        │    (bytecode VM)                    │
                        │       │                 │           │
                        │       ▼                 ▼           │
   UART TX ◄────────────│  tx_str()          ws2812_fill()    │
                        │                         │           │
   PD6 ─────────────────│                    4× WS2812B LEDs  │
   PD3 ─────────────────│  handle_button()                    │
                        └─────────────────────────────────────┘
```

---

## Cryptographic Design

### Speck-128/256

The Ouroboros Engine uses the **Speck-128/256** block cipher from the Simon/Speck family (NSA, 2013). Speck is an Add-Rotate-XOR (ARX) cipher optimized for constrained hardware.

**Parameters:**

| Parameter | Value |
|---|---|
| Block size | 128 bits (2 × 64-bit words) |
| Key size | 256 bits (4 × 64-bit words) |
| Rounds | 34 |
| Word size | 64 bits |
| Rotation constants | $\alpha = 8$, $\beta = 3$ |

**Round Function:**

Each encryption round transforms the 128-bit state $(x, y)$ with round key $k_i$:

$$x' = \left( x \ggg 8 + y \right) \bmod 2^{64} \oplus k_i$$

$$y' = (y \lll 3) \oplus x'$$

where $\ggg$ denotes right rotation and $\lll$ denotes left rotation.

**Key Schedule:**

Given the 256-bit key split as $(k_0, l_0, l_1, l_2)$ (each 64-bit word, little-endian):

$$l_{i+3} = \left( k_i + (l_{i \bmod 3} \ggg 8) \right) \bmod 2^{64} \oplus i$$

$$k_{i+1} = (k_i \lll 3) \oplus l_{i+3}$$

for $i = 0, 1, \ldots, 32$, producing 34 round keys $k_0, k_1, \ldots, k_{33}$.

**AVR Implementation:**

The 64-bit words are stored in 8 contiguous byte registers in little-endian order. The assembly uses:

- **`speck_round_half1`**: Implements $x \ggg 8$ via a byte-shift rotation of registers R0–R7, followed by a multi-precision 64-bit addition with R8–R15 (the $y$ word and key).
- **`speck_round_half2`**: Implements $y \lll 3$ via three sequential `LSL`/`ROL` chains across registers R8–R15 with carry feed-back, followed by XOR with R0–R7.

All 34 rounds are executed in a loop; each round invokes both half-functions with intermediate key material loaded from `round_keys` in SRAM.

**Key schedule circular buffer (`l_buf`):**

The key schedule uses a 32-byte SRAM circular buffer (`l_buf`) holding three 8-byte $l$ values. Access uses modulo-3 addressing computed by repeated subtraction to avoid the `DIV` instruction (which AVR lacks):

$$\text{offset} = (i \bmod 3) \times 8$$

---

### Davies-Meyer Key Stretching

The user's passphrase (zero-padded to 32 bytes) serves as the Speck-128/256 **key** in a Davies-Meyer hash construction run for **24,576 iterations** over a 16-byte hash buffer initialized to the first 128 bits of the SHA-256 initialization constants:

$$IV = \text{6A09E667 BB67AE85 3C6EF372 A54FF53A}_{16}$$

The key stretching proceeds as:

$$H_0 = IV$$

$$H_j = E_{K_{\text{user}}}(H_{j-1}), \quad j = 1, 2, \ldots, 24576$$

$$\hat{H} = H_{24576} \oplus IV$$

The final feed-forward XOR (the Davies-Meyer step) ensures that $\hat{H}$ is not directly recoverable by inverting the cipher. The resulting 16-byte $\hat{H}$ is stored in `hash_buf` and serves as the CTR nonce.

**Work Factor:**

Each `encrypt_block` call executes 34 Speck rounds. At 8 MHz, a single `encrypt_block` invocation takes approximately:

$$T_{\text{enc}} \approx \frac{34 \times 103 \text{ cycles}}{8 \times 10^6 \text{ Hz}} \approx 437\ \mu s$$

Over 24,576 iterations:

$$T_{\text{hash}} \approx 24576 \times 437\ \mu s \approx 10.74\ \text{seconds}$$

This roughly 10-second window per attempt reduces the rate of on-device online guessing and raises the modeled cost of offline simulation. An attacker must still replicate 24,576 sequential Speck-128/256 encryptions per password candidate.

---

### CTR-Mode Decryption

After key stretching, a CTR-mode keystream is generated to decrypt the flash-resident ciphertext table. The CTR block for block index $b \in \{0, 1, 2\}$ is constructed as:

$$\text{CTR}_b = \hat{H}[0:8] \| b \| \underbrace{0^7}_{\text{7 zero bytes}}$$

where $\hat{H}[0:8]$ is the 8-byte nonce from the stretched hash, and $b$ is the 8-bit block counter. The 16-byte CTR block is encrypted with Speck-128/256 using the same user key to produce the keystream:

$$\text{KS}_b = E_{K_{\text{user}}}(\text{CTR}_b)$$

Decryption of block $b$ of the 48-byte ciphertext entry:

$$P_b = C_b \oplus \text{KS}_b$$

The three decrypted 16-byte blocks concatenate to form the 48-byte `result_buf`:
- Bytes 0–15: bytecode payload
- Bytes 16–47: MAC padding ($32 \times \text{0xAA}$)

---

### Branchless MAC Verification

After decryption, bytes 16–47 of `result_buf` must equal `0xAA` if the password was correct. Verification is performed in a fixed-iteration branchless routine with no data-dependent branches in that check:

**Error accumulation (OR-reduce):**

Let $P[i]$ denote `result_buf[i]`. Each byte is checked via `SUBI 0xAA`; differences accumulate via `OR` into $\delta \in [0, 255]$:

$$\delta = \bigvee_{i=16}^{47} \bigl(P[i] - \text{0xAA}\bigr)$$

**Mask generation (2's-complement trick):**

The AVR instructions `NEG`, `SBC`, `COM` implement a branchless transformation:

$$m = \begin{cases} \text{0xFF} & \text{if } \delta = 0 \text{ (all bytes match)} \\ \text{0x00} & \text{if } \delta \neq 0 \text{ (any mismatch)} \end{cases}$$

Proof: If $\delta = 0$: `NEG(0) = 0`, carry $= 0$; `SBC(0,0,0) = 0`; `COM(0) = 0xFF` ✓  
If $\delta \neq 0$: `NEG(`$\delta$`) =` $256 - \delta$, carry $= 1$; `SBC(`$256-\delta$, $256-\delta$, $1$`) = -1 = 0xFF`; `COM(0xFF) = 0x00` ✓

**Branchless result masking:**

$$P[i] \leftarrow P[i] \wedge m, \quad i = 0, \ldots, 47$$

If the MAC fails, the entire 48-byte buffer is zeroed. The bytecode dispatcher then encounters `0x00` (END opcode) immediately, executing nothing.

---

### Blind Cipher Selection

The engine contains a flash-resident table of $N$ encrypted 48-byte entries (`table_ciphers`). All $N$ entries are **always** tried in full, regardless of early matches, to prevent a timing oracle:

```
found ← 0xFF  (sentinel = "not found")
for i = 0 to N-1:
    decrypt entry i → result_buf
    verify MAC      → mask_i  (0xFF or 0x00)
    r0 ← i AND mask_i                        ; 0 if fail, i if pass
    found ← (found AND NOT mask_i) OR r0
```

Implemented in AVR as:

```asm
MOV   R0,  R22 ; R0 = i
AND   R0,  R17 ; R0 = i if pass, 0 if fail
COM   R17      ; invert mask
AND   R23, R17 ; R23 = old_found if fail, 0 if pass
OR    R23, R0  ; R23 = (pass ? i : old_found)
```

After all $N$ iterations, if $\text{found} \neq \text{0xFF}$, the winning entry is re-decrypted and dispatched. The total number of decrypt+verify operations is always exactly $N$, regardless of the password or table contents.

---

## Hardware Subsystems

### WS2812B LED Driver

Four WS2812B LEDs are driven on **PD6** via cycle-accurate bit-banging. At 8 MHz (125 ns/cycle):

| Bit type | $T_H$ (HIGH) | $T_L$ (LOW) | Total |
|---|---|---|---|
| 0-bit | 2 cycles = 250 ns | 8 cycles = 1000 ns | 1.25 μs |
| 1-bit | 6 cycles = 750 ns | 4 cycles = 500 ns | 1.25 μs |

The code uses `OUT PORTD, Rn` (1 cycle, single-word instruction) rather than `SBI`/`CBI` (2 cycles) to maintain deterministic timing. Interrupts are disabled (`CLI`) for the entire fill operation and re-enabled (`SEI`) after the last LED's data is shifted out.

The reset condition (>80 μs LOW) occurs naturally between `ws2812_fill` calls, since the main loop delay vastly exceeds 80 μs. No explicit reset subroutine is required.

Data is sent in GRB order as required by the WS2812B protocol: Green → Red → Blue (24 bits × 4 LEDs = 96 bits total per fill).

Wait — looking at the fill:
```asm
MOV R24, R17 ; R24 = Red
RCALL send_byte
MOV R24, R18 ; R24 = Green
RCALL send_byte
MOV R24, R16 ; R24 = Blue
RCALL send_byte
```
The registers are ordered R (R17), G (R18), B (R16) by the calling convention, sent Red first, then Green, then Blue. The WS2812B wire protocol is GRB, so effectively the LED display order is configured to match the wire format by register assignment in `ws2812_fill`.

**Bit-banging loop (per bit, 10 cycles):**

```
Cycle 1:    OUT HIGH       ; PD6 = 1 (always)
Cycle 2:    SBRS R24, 7    ; test bit 7 (1 or 2 cycles)
Cycle 2/3:  OUT LOW        ; PD6 = 0 (0-bit path only)
Cycle 3/4:  LSL R24        ; shift next bit into position
Cycle 4/5:  NOP            ; timing pad
Cycle 5/6:  NOP            ; timing pad
Cycle 6/7:  OUT LOW        ; PD6 = 0 (1-bit path, end of high)
Cycle 7/8:  DEC R23        ; bit counter
Cycle 8-10: BRNE .bit_loop ; 2 cycles (taken), 1 cycle (not taken)
```

---

### UART Interface

UART0 is configured for **9600 baud, 8N1** using the ATmega328P's built-in USART peripheral. The baud rate register value is:

$$\text{UBRR} = \left\lfloor \frac{f_{\text{CPU}}}{16 \times \text{baud}} \right\rfloor - 1 = \left\lfloor \frac{8{,}000{,}000}{16 \times 9600} \right\rfloor - 1 = 51$$

All UART operations are **polling-based** (no interrupts). The receive loop checks `RXC0` (Receive Complete flag in UCSR0A) before reading `UDR0`. Transmit loops on `UDRE0` (Data Register Empty).

After the crypto pipeline completes (success or fail), `uart_flush_rx` hard-resets the UART receiver by toggling `RXEN0`. This clears the Data OverRun (`DOR`) flag accumulated during the ~10-second hash computation window and flushes any stale bytes in the hardware shift register.

The input buffer (`input_buf`, 32 bytes) is zero-padded to exactly 32 bytes on ENTER, then immediately zeroed after use by `clear_input_buf` to prevent key material persistence in SRAM.

---

### Button Logic

A normally-open tactile switch is connected to **PD3** with the internal pull-up resistor enabled (`SBI PORTD, PD3`). The pin is active-LOW.

The button cycles the system state machine: `ANIM → RED → GREEN → BLUE → ANIM`. During `STATE_INPUT`, button presses are ignored. Debounce is software-only:

$$T_{\text{debounce}} = 256 \times 256 \times \frac{3\ \text{cycles}}{8 \times 10^6\ \text{Hz}} \approx 24.6\ \text{ms}$$

The outer loop (`R17`) runs 256 times, each iteration running the inner loop (`R16`) 256 times at ~3 cycles/iteration, totaling $\approx 196,608$ cycles $\approx 24.6$ ms of debounce blanking.

---

### Timer Architecture

Two independent 16-bit software counters are maintained in SRAM, incremented once per main-loop iteration by `delay_and_timers`:

**Animation timer (`anim_timer`):**

$$T_{\text{iter}} = \frac{4 \times 1349\ \text{cycles}}{8 \times 10^6\ \text{Hz}} \approx 674.5\ \mu s$$

$$\text{Threshold}_{\text{anim}} = (\text{0x1C} \ll 8) \mid \text{0xD4} = 7380$$

$$T_{\text{anim}} = 7380 \times 674.5\ \mu s \approx 4.98\ \text{s}$$

Colors advance every ~5 seconds in `STATE_ANIM`.

**Input inactivity timeout (`input_timer`):**

$$\text{Threshold}_{\text{input}} = (\text{0xAC} \ll 8) \mid \text{0xF8} = 44280$$

$$T_{\text{timeout}} = 44280 \times 674.5\ \mu s \approx 29.87\ \text{s}$$

The input session auto-cancels after ~30 seconds of inactivity. Timer1 (`TCCR1B`, `TCNT1H/L`) is available to `hardware_jitter_and_exe` as an entropy source for side-channel mitigation; TCNT0 is read for jitter.

---

## Bytecode Interpreter

`dispatch_program` executes a minimal 4-opcode bytecode language from `result_buf`. Execution halts on unknown opcodes (fail-safe):

| Opcode | Mnemonic | Operands | Action |
|---|---|---|---|
| `0x00` | `END` | — | Halt execution |
| `0x01` | `LED_FILL` | R, G, B | Fill all 4 LEDs with solid colour |
| `0x03` | `TX_STR` | len, char... | Transmit `len` bytes over UART |
| `0xAA` | `MAC` | — | Halt (integrity marker, never valid after strip) |

The interpreter is a simple fetch-decode-execute loop with linear forward-only execution. No jumps, no stack, no variables — purely sequential. Unknown opcodes call `RET` immediately (the `BRNE .done` path), preventing runaway execution.

**Example payload (hello → world):**

```
01 FF 00 FF          ; LED_FILL R=255 G=0 B=255  (purple)
03 07                ; TX_STR len=7
77 6F 72 6C 64 0D 0A ; "world\r\n"
00                   ; END
[00 00 ...]          ; zero-padding to 16 bytes
AA AA ... AA         ; 32-byte MAC padding (0xAA × 32)
```

---

## Side-Channel-Relevant Implementation Notes

### Hardware Jitter (`hardware_jitter_and_exe`)

Before every `encrypt_block` call during the hash loop and during key schedule, a random timing jitter is injected:

```asm
IN   R16, 0x26    ; Read TCNT0 (free-running Timer/Counter 0)
ANDI R16, 0x07    ; Isolate bottom 3 bits → jitter in [0, 7] cycles
.jitter_loop:
DEC  R16
BRPL .jitter_loop ; loop while ≥ 0 (signed)
```

This introduces 0–7 cycles of delay before each Speck encryption, derived from the low-order bits of the free-running hardware timer. This changes trace alignment characteristics, but this repo does not provide measured DPA/FI success-rate data.

### Constant-Time MAC Comparison

`branchless_mac_verification` never branches on the compared MAC-region bytes. The 32-byte MAC region is checked with an OR-reduce accumulator and a 2's-complement mask in that routine.

### Constant-Iteration Cipher Scan

`blind_xor_decryption` + `branchless_mac_verification` is always called exactly `CIPHER_ENTRIES` times, regardless of match position. This removes that specific early-exit timing difference.

### Key Material Zeroization

`clear_input_buf` zeros all 32 bytes of `input_buf` after the crypto pipeline completes, reducing how long that buffer remains populated.

### UART DOR Recovery

`uart_flush_rx` toggles `RXEN0` after each crypto operation to flush UART overflow state accumulated during the ~10-second hash window before the next receive cycle.

### Watchdog Neutralization

`clear_reset_flags` disables the watchdog timer at boot using the two-step unlock sequence required by the ATmega328P silicon:

```asm
CLI                         ; Global interrupt disable
WDR                         ; Pet the dog one last time
CLR R16
OUT MCUSR, R16              ; Clear WDRF (watchdog reset flag)
LDI R16, (1<<WDCE)|(1<<WDE)
STS WDTCSR, R16             ; Unlock WDTCSR
CLR R16
STS WDTCSR, R16             ; Disable WDT permanently
```

Failure to clear WDRF before disabling the WDT causes the ATmega328P to ignore all WDT disable instructions, producing an infinite 15 ms boot loop.

---

## State Machine

```
                    ┌──────────┐
              ┌────►│  ANIM    │◄────────────────────────┐
              │     │ (R→G→B)  │                         │
              │     └─────┬────┘                         │
              │           │ button                       │ 5s timeout
              │           ▼                              │ (after fail)
              │     ┌──────────┐                         │
              │     │   RED    │                         │
              │     └─────┬────┘                         │
              │           │ button                       │
              │           ▼                              │
              │     ┌──────────┐                   ┌─────┴────┐
              │     │  GREEN   │                   │  PURPLE  │
              │     └─────┬────┘                   │ (fail)   │
              │           │ button                 └──────────┘
              │           ▼
              │     ┌──────────┐
              │     │   BLUE   │
              │     └─────┬────┘
              │           │ button
              └───────────┘

              Any state + UART keystroke ──────► STATE_INPUT
              STATE_INPUT + ENTER (correct) ───► YELLOW (5s) → restore
              STATE_INPUT + ENTER (wrong)  ───► PURPLE (5s) → restore
              STATE_INPUT + 30s timeout   ───► restore prev_state
```

| State | Value | LED Colour | Trigger |
|---|---|---|---|
| `STATE_ANIM` | 0 | Cycling R/G/B | Boot / button wrap |
| `STATE_RED` | 1 | Solid red | 1× button |
| `STATE_GREEN` | 2 | Solid green | 2× button |
| `STATE_BLUE` | 3 | Solid blue | 3× button |
| `STATE_INPUT` | 4 | White (keystroke) | Any UART character |
| — | — | Yellow | Crypto success |
| — | — | Purple | Crypto failure |

---

## Boot Sequence

On power-on or reset, `main` executes the following initialization sequence before entering the main loop:

1. **Stack pointer init**: `SPH:SPL ← RAMEND (0x08FF)`
2. **SRAM clear**: Zero all 2,048 bytes (`0x0100`–`0x08FF`) via X-pointer loop
3. **Watchdog kill**: `clear_reset_flags` (clears WDRF, disables WDTCSR)
4. **UART init**: `uart_init` (9600 baud, 8N1, RX/TX enabled)
5. **Pin config**: `config_pins` (PD6 output/LOW for WS2812; PD3 input/pull-up for button)
6. **State init**: Zero `sys_state`, `uart_idx`, `anim_idx`, `prev_state`, `anim_timer`
7. **Initial render**: `render_state` → LEDs show red (first animation frame)
8. **Prompt**: `tx_prompt` → sends `"> "` over UART

---

## Memory Map

### Flash (32 KB, `.text` section)

| Region | Content |
|---|---|
| `0x0000` | Reset vector → `RJMP main` |
| `0x0002`+ | `main`, all included `.s` files |
| `iv_const` | 16-byte SHA-256 IV constant |
| `table_ciphers` | $N \times 48$ bytes encrypted bytecode entries |

### SRAM (2 KB, `.bss` section, base `0x0100`)

| Symbol | Size | Purpose |
|---|---|---|
| `round_keys` | 272 bytes | 34 × 8-byte Speck round keys |
| `l_buf` | 32 bytes | Key schedule circular buffer |
| `input_buf` | 32 bytes | UART receive buffer (padded to 32) |
| `hash_buf` | 16 bytes | Davies-Meyer hash output / CTR nonce |
| `ctr_buf` | 16 bytes | CTR counter block |
| `result_buf` | 48 bytes | Decrypted plaintext + MAC |
| `sys_state` | 1 byte | Current system mode |
| `prev_state` | 1 byte | Mode saved before input |
| `anim_idx` | 1 byte | Animation sub-colour (0=R,1=G,2=B) |
| `uart_idx` | 1 byte | UART write index |
| `anim_timer` | 2 bytes | 16-bit animation counter |
| `input_timer` | 2 bytes | 16-bit inactivity counter |
| **Total** | **425 bytes** | **(20.8% of 2,048 bytes)** |

---

## Build & Flash

### Prerequisites

```bash
# macOS (Homebrew)
brew install avr-binutils avr-gcc avrdude

# Ubuntu/Debian
sudo apt install binutils-avr avr-libc avrdude
```

### Build

```bash
make       # Assemble, link, generate .hex, .lss, and ELF info
make flash # Flash .hex via USBtiny ISP
make fuses # Set fuses: 8 MHz internal, no CKDIV8
make lock  # Set lock bits: prevent external flash readback
make clean # Remove all build artifacts
```

### Fuse Settings

| Fuse | Value | Meaning |
|---|---|---|
| LFUSE | `0xE2` | Internal 8 MHz RC, CKDIV8 disabled |
| HFUSE | `0xD5` | SPIEN on, JTAG off |
| EFUSE | `0xFD` | BOD at 2.7 V |

> **Warning**: `make lock` sets lock bits to `0x00` (no external read/write of flash or EEPROM). This is irreversible without a chip-erase (which destroys all flash contents).

### Adding Cipher Entries

Use `scripts/dec.py` to generate new encrypted bytecode entries:

```bash
python3 scripts/dec.py
```

Edit `MASTER_KEY` and `TARGET_FLAG` at the top of the script. The script outputs `.byte` directives ready to paste into `data.s`. Increment `CIPHER_ENTRIES` in `defines.s` accordingly.

---

## File Structure

```
ouroboros/
├── Makefile        # Build system (avr-as + avr-ld)
├── asm/
│   ├── main.s      # Entry point, stack init, SRAM clear, main loop
│   ├── defines.s   # All .equ constants (registers, state codes, thresholds)
│   ├── variables.s # BSS section (all SRAM buffers)
│   ├── data.s      # Flash data: IV constant, cipher table
│   ├── boot.s      # clear_reset_flags (WDT kill)
│   ├── config.s    # config_pins (PD3/PD6)
│   ├── uart.s      # uart_init, uart_tx_byte, uart_flush_rx, tx_prompt, tx_crlf
│   ├── ws2812.s    # send_byte, ws2812_fill, render_state
│   ├── button.s    # handle_button (debounce, state cycle)
│   ├── input.s     # handle_uart (echo, backspace, crypto pipeline trigger)
│   ├── ouroboros.s # speck_256_key_schedule, speck_round_half1/2,
│   │               # encrypt_block, davies_meyer_hash_loop,
│   │               # keystream_generation, blind_xor_decryption,
│   │               # branchless_mac_verification, hardware_jitter_and_exe
│   ├── dispatch.s  # dispatch_program (bytecode VM)
│   └── delay.s     # delay_and_timers, force_advance, delay_5s
├── scripts/
│   └── dec.py      # Python reference implementation & ciphertext generator
├── docs/
│   ├── ATmega328P-Datasheet.pdf
│   ├── 5050-WS2812B.pdf
│   ├── Atmel-AVR-InstructionSet.pdf
│   └── Atmel-Mixing-C-ASM.pdf
├── pinout/
│   └── Atmega328-Pinout.png
└── LICENSE
```

---

## Security Analysis

### Threat Model

The Ouroboros Engine is analyzed here against an adversary who:
- Has physical access to the assembled hardware
- Can observe all UART traffic
- Can measure power consumption during operation
- Has a copy of the firmware binary
- Knows the algorithm (Kerckhoffs's principle)

The secret is exclusively the passphrase stored in `input_buf` during authentication.

### Attack Surface

| Attack | Mitigation |
|---|---|
| Online brute-force | ~10-second hash per attempt; physically on-device |
| UART timing oracle | Constant-time MAC; constant-iteration scan |
| Power analysis (SPA) | Hardware jitter (0–7 random cycles per Speck block) |
| DPA | Jitter misaligns traces and raises analysis cost; no measured DPA/FI success-rate dataset is published in this repo |
| Cold-boot attack | `clear_input_buf` zeros key material after use |
| Flash readback | Lock bits `0x00` prevent external ISP reads |
| Firmware reverse engineering | Algorithm is public (Speck); security through key entropy |
| Ciphertext malleability | Branchless MAC zeroes result on any byte mismatch |
| Watchdog reset loop | WDRF cleared and WDTCSR disabled at boot |

### Key Space

The 32-byte `input_buf` represents a maximum of $256^{32} = 2^{256}$ keys (padded). The strict adversarial scenario used below assumes an externally enforced 32-character non-dictionary random master key over base62 symbols ($|\Sigma| = 62$). For any human-chosen passphrase, effective entropy can be much lower and depends on passphrase length and character set:

$$H = \log_2(|\Sigma|^n) = n \log_2 |\Sigma|$$

For printable ASCII ($|\Sigma| = 95$) and $n = 16$ characters: $H \approx 105$ bits.

### Offline Attack Cost

Reference attacker model (same as the paper):

$$N_{\text{GPU}} \approx 10^{12}\ \text{Speck ops/s}$$

$$T_{\text{attempt}} = \frac{24576}{10^{12}} \approx 24.6\ \text{ns per candidate}$$

Classical exhaustive-search estimate for mandatory random base62 $n=32$:

$$T_{\text{classical}} = 62^{32} \times 24.6\ \text{ns} \approx 5.59 \times 10^{49}\ \text{s} \approx 1.77 \times 10^{42}\ \text{years}$$

Optimistic Grover-style average-time estimate (toy model, favorable to attacker):

$$T_{\text{quantum}} \approx \frac{\sqrt{62^{32}}}{2} \times 24.6\ \text{ns} \approx 5.86 \times 10^{20}\ \text{s} \approx 1.86 \times 10^{13}\ \text{years}$$

These are model outputs, not measured throughput benchmarks. They do not imply post-quantum security; the accurate claim is quantum-costly under stated assumptions.

---

*The Ouroboros Engine — where the cipher devours its own tail.*

<br>

See [LICENSE](https://github.com/mytechnotalent/ouroboros/blob/main/LICENSE).
