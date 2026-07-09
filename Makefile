# ===================================================================
# Project:       The Ouroboros Engine
# Author:        Kevin Thomas
# E-Mail:        ket189@pitt.edu
# Version:       1.0.0
# Date:          2026-06-25
# Target Device: ATmega328P
# Clock Freq:    8 MHz
# Toolchain:     avr-as, avr-ld, avrdude
# Description:   Makefile
# ===================================================================

# MCU and architecture settings
MCU     = atmega328p
LD_ARCH = avr5 
F_CPU   = 8000000
TARGET  = ouroboros

# Source and Object files
SRC     = asm/main.s
OBJ     = $(SRC:.s=.o)

# Toolchain definitions
AS      = avr-as
LD      = avr-ld
OBJCOPY = avr-objcopy
OBJDUMP = avr-objdump
READELF = avr-readelf
SIZE    = avr-size

# Flags
ASFLAGS = -mmcu=$(MCU) -I asm
LDFLAGS = -m $(LD_ARCH) --defsym __DATA_REGION_ORIGIN__=0x800100

# Default target
all: $(TARGET).hex disasm readelf
	@$(SIZE) $(TARGET).elf

# Rule to assemble .s files into .o object files
%.o: %.s
	$(AS) $(ASFLAGS) -o $@ $<

# Rule to link .o files into the final .elf
$(TARGET).elf: $(OBJ)
	$(LD) $(LDFLAGS) -o $@ $^

# Rule to extract the hex file from the .elf
$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -j .text -j .data -O ihex $< $@

# Generate a disassembly listing file (.lss) from the ELF
disasm: $(TARGET).elf
	$(OBJDUMP) -h -d $< > $(TARGET).lss

# Dump the raw ELF header and section info to a text file
readelf: $(TARGET).elf
	$(READELF) -a $< > $(TARGET)_elf_info.txt

# Clean up build artifacts (Updated to include .lss and .txt)
clean:
	rm -f $(TARGET).elf $(TARGET).hex $(TARGET).lss $(TARGET)_elf_info.txt $(OBJ)

# Flashing and fuses
flash: all
	avrdude -c usbtiny -p $(MCU) -U flash:w:$(TARGET).hex:i

# Set lock bits: prevent flash readback via ISP/debugWIRE
# BLB = 0x00: no read/write of boot/app from external programming
lock:
	avrdude -c usbtiny -p $(MCU) -U lock:w:0x00:m

# Set fuses for 8MHz internal RC (no crystal)
# LFUSE = 0xE2: internal 8MHz, no CKDIV8
# HFUSE = 0xD5
# EFUSE = 0xFD
fuses:
	avrdude -c usbtiny -p $(MCU) \
		-U lfuse:w:0xE2:m \
		-U hfuse:w:0xD5:m \
		-U efuse:w:0xFD:m

# PHONY targets
.PHONY: all clean flash lock fuses disasm readelf
