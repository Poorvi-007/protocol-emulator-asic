# Protocol Emulator ASIC

A programmable digital protocol emulator designed for the **Jane Street Protocol Emulator ASIC Competition** using the **Tiny Tapeout / IHP 130nm CMOS5L** flow.

The goal of this project is to create a small, reprogrammable hardware engine that can emulate different digital communication protocols through programmable instructions rather than implementing each protocol as fixed hardware.

## Project Status

Current RTL implementation includes:

- Programmable 16-bit instruction memory
- Serial instruction loader
- Program execution engine
- GPIO input and output
- Conditional branching
- Wait and edge-detection operations
- 8-bit shift register
- SHIFT_IN and SHIFT_OUT operations
- Cocotb verification
- Icarus Verilog simulation
- GTKWave waveform inspection
- Tiny Tapeout / LibreLane ASIC flow

### Current verification

The current instruction set has **9 Cocotb tests**, and the latest stable RTL checkpoint passes:

**9/9 tests**

The current stable instruction set contains:

1. NOP
2. WRITE
3. READ
4. WAIT
5. WAIT_EDGE
6. JUMP
7. JUMP_IF_HIGH
8. JUMP_IF_LOW
9. SHIFT_IN
10. SHIFT_OUT
