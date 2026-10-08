# Protocol Emulator ASIC

A programmable ASIC protocol emulator designed to execute configurable digital communication protocols.

## How it works

The design contains a small programmable protocol engine with instruction memory, a serial program loader, GPIO inputs and outputs, timing control, branching, edge detection, and shift operations.

Programs are loaded into the instruction memory through the serial loader. The protocol engine then executes the loaded instructions cycle by cycle.

The instruction set currently includes:

- NOP
- WRITE
- READ
- WAIT
- WAIT_EDGE
- JUMP
- JUMP_IF_HIGH
- JUMP_IF_LOW
- SHIFT_IN
- SHIFT_OUT

This programmable architecture is intended to support protocols such as UART, SPI, and I2C through software-defined instruction sequences rather than fixed hardware peripherals.

## How to test

The project includes Cocotb tests and an Icarus Verilog simulation environment.

From the `test` directory, run:

```bash
cd /c/Users/sshri/Desktop/protocol-emulator-asic/test
make
