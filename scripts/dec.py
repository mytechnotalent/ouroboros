# ==============================================================================
# Project:       The Ouroboros Engine
# Author:        Kevin Thomas
# E-Mail:        ket189@pitt.edu
# Version:       1.0.0
# Date:          2026-06-26
# Target Device: ATmega328P
# Clock Freq:    8 MHz
# Toolchain:     Python 3, avr-as, avr-ld, avrdude
# Description:   Python reference implementation & ciphertext generator
# ==============================================================================

import struct

# ==============================================================================
# CONFIGURATION
# ==============================================================================
MASTER_KEY = "hello"
TARGET_FLAG = "world"

# IV Constants (SHA-256 initialization constants)
IV = bytes([
    0x6A, 0x09, 0xE6, 0x67, 0xBB, 0x67, 0xAE, 0x85,
    0x3C, 0x6E, 0xF3, 0x72, 0xA5, 0x4F, 0xF5, 0x3A
])

MASK64 = 0xFFFFFFFFFFFFFFFF

# ==============================================================================
# SPECK-256/128 CORE
# ==============================================================================


def ROR8(x):
    """Rotate a 64-bit value right by 8 bits.

    Parameters
    ----------
    x : int
        64-bit unsigned integer to rotate.

    Returns
    -------
    int
        Rotated 64-bit value.
    """
    return ((x >> 8) | (x << 56)) & MASK64


def ROL3(x):
    """Rotate a 64-bit value left by 3 bits.

    Parameters
    ----------
    x : int
        64-bit unsigned integer to rotate.

    Returns
    -------
    int
        Rotated 64-bit value.
    """
    return ((x << 3) | (x >> 61)) & MASK64


def speck_encrypt(plaintext, key):
    """Encrypt a 128-bit block with Speck-128/256.

    Parameters
    ----------
    plaintext : bytes
        16-byte plaintext block.
    key : bytes
        32-byte (256-bit) Speck key.

    Returns
    -------
    bytes
        16-byte ciphertext block.
    """
    x, y = struct.unpack('<QQ', plaintext)
    # Key Schedule
    K = [0] * 34
    k = list(struct.unpack('<QQQQ', key))
    b = k[0]
    a = k[1:]
    K[0] = b
    for i in range(33):
        a_idx = i % 3
        a_val = a[a_idx]
        a_val = (ROR8(a_val) + b) & MASK64
        a_val ^= i
        b = ROL3(b) ^ a_val
        a[a_idx] = a_val
        K[i + 1] = b
    # Encryption
    for i in range(34):
        x = (ROR8(x) + y) & MASK64
        x ^= K[i]
        y = ROL3(y) ^ x
    return struct.pack('<QQ', x, y)


# ==============================================================================
# OUROBOROS PIPELINE
# ==============================================================================


def _ouroboros_crypt(payload, key):
    """Encrypt a payload through the full Ouroboros pipeline.

    The pipeline applies: Davies-Meyer hash stretching (24,576 iterations),
    feed-forward XOR, and CTR-mode encryption.

    Parameters
    ----------
    payload : bytes
        48-byte plaintext payload (16 bytes data + 32 bytes MAC padding).
    key : bytes
        32-byte padded key.

    Returns
    -------
    bytes
        48-byte ciphertext.

    Raises
    ------
    ValueError
        If payload is not 48 bytes or key is not 32 bytes.
    """
    if len(payload) != 48:
        raise ValueError("Payload must be 48 bytes.")
    if len(key) != 32:
        raise ValueError("Key must be 32 bytes.")
    # Davies-Meyer Hash Stretch (24,576 iterations)
    print("Hashing key (simulating AVR delay)...")
    hash_buf = bytearray(IV)
    for _ in range(24576):
        hash_buf = bytearray(speck_encrypt(hash_buf, key))
    # Feed-forward XOR
    for i in range(16):
        hash_buf[i] ^= IV[i]
    # CTR Keystream Generation & XOR
    ciphers = bytearray()
    for block_num in range(3):
        # Nonce [0:8] + Counter [8:9] + Padding [9:16]
        ctr_buf = (
            hash_buf[0:8]
            + bytes([block_num])
            + (b'\x00' * 7)
        )
        keystream = speck_encrypt(ctr_buf, key)
        for i in range(16):
            ciphers.append(
                payload[block_num * 16 + i] ^ keystream[i]
            )
    return bytes(ciphers)


def build_bytecode(key_str, flag_str):
    """Build a bytecode program for the v3 bytecode dispatcher.

    Parameters
    ----------
    key_str : str
        User input string (e.g. "hello").
    flag_str : str
        Expected output string (e.g. "world").

    Returns
    -------
    bytes
        48-byte Ouroboros payload (16 bytes bytecode + 32 bytes 0xAA MAC),
        encrypted via the standard Davies-Meyer + Speck-CTR pipeline.
    """
    user_key = key_str.encode().ljust(32, b'\x00')
    flag_bytes = flag_str.encode() + b'\r\n'
    # Bytecode: LED_FILL purple + TX_STR + END
    prog = bytes([0x01, 0xFF, 0x00, 0xFF])  # LED_FILL(255,0,255)
    prog += bytes([0x03, len(flag_bytes)])   # TX_STR(len)
    prog += flag_bytes
    prog += bytes([0x00])                     # END
    prog = prog.ljust(16, b'\x00')
    mac = b'\xAA' * 32
    payload = prog + mac
    return _ouroboros_crypt(payload, user_key)


def print_asm_format(label, data):
    """Print data as AVR assembly .byte directives.

    Parameters
    ----------
    label : str
        Label name for the data block.
    data : bytes
        Byte data to format.
    """
    print(f"{label}:")
    for i in range(0, len(data), 4):
        chunk = data[i:i + 4]
        hex_str = ", ".join([f"0x{chunk[j]:02X}" for j in range(len(chunk))])
        print(f"  .byte {hex_str:<26} ; Data chunk {i // 4}")


# ==============================================================================
# EXECUTION
# ==============================================================================

if __name__ == "__main__":
    # v3: generate bytecode payloads (LED_FILL + TX_STR + MAC)
    entries = [(MASTER_KEY, TARGET_FLAG), ("foo", "bar")]
    print("\n; === Copy and paste into asm/data.s ===\n")
    print_asm_format("iv_const", IV)
    print(";")
    print("; Bytecode ciphers (v3 — Ouroboros pipeline)")
    ct_all = b"".join(build_bytecode(k, f) for k, f in entries)
    print_asm_format("table_ciphers", ct_all)
    print()
    print(f"; CIPHER_ENTRIES = {len(entries)}")
