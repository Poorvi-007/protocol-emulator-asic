# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


async def send_bit(dut, bit_value):
    """Send one serial bit while keeping the loader in programming mode."""
    dut.ui_in.value = ((bit_value & 1) << 0) | (1 << 1) | (1 << 2)
    await ClockCycles(dut.clk, 1)

    # Keep programming mode active between bits.
    dut.ui_in.value = 4
    await ClockCycles(dut.clk, 1)


async def send_instruction(dut, instruction):
    for bit_index in range(15, -1, -1):
        await send_bit(dut, (instruction >> bit_index) & 1)


@cocotb.test()
async def test_wait_instruction(dut):
    dut._log.info("WAIT instruction test")

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Enter programming mode.
    dut.ui_in.value = 4
    await ClockCycles(dut.clk, 1)

    # Program 0: WRITE 1
    await send_instruction(dut, 0x1001)

    # Program 1: WAIT 3 cycles
    await send_instruction(dut, 0x3003)

    # Program 2: WRITE 4
    await send_instruction(dut, 0x1004)

    # Return to normal execution mode.
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 1)

    # Allow the first instruction to execute.
    await ClockCycles(dut.clk, 1)
    assert dut.uo_out.value == 1

    # WAIT should keep the output at 1 for the remaining wait cycles.
    await ClockCycles(dut.clk, 3)
    assert dut.uo_out.value == 1

    # WAIT should finish and execute WRITE 4.
    await ClockCycles(dut.clk, 2)
    assert dut.uo_out.value == 4


@cocotb.test()
async def test_wait_edge(dut):
    dut._log.info("WAIT_EDGE instruction test")

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Enter programming mode.
    dut.ui_in.value = 4
    await ClockCycles(dut.clk, 1)

    # Program 0: WRITE 1
    await send_instruction(dut, 0x1001)

    # Program 1: WAIT_EDGE
    await send_instruction(dut, 0x4000)

    # Program 2: WRITE 4
    await send_instruction(dut, 0x1004)

    # Return to normal execution mode.
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 1)

    # Allow WRITE 1 to execute.
    await ClockCycles(dut.clk, 2)
    assert dut.uo_out.value == 1

    # Keep input unchanged; WAIT_EDGE should keep waiting.
    await ClockCycles(dut.clk, 3)
    assert dut.uo_out.value == 1

	# Change an input bit to release WAIT_EDGE.
    dut.ui_in.value = 1

    # Give WAIT_EDGE one clock to detect the change,
    # then another clock to execute WRITE 4.
    await ClockCycles(dut.clk, 3)

    assert dut.uo_out.value == 4
	
@cocotb.test()
async def test_jump_if_high_instruction(dut):
    dut._log.info("JUMP_IF_HIGH instruction test")

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Enter programming mode.
    dut.ui_in.value = 4
    await ClockCycles(dut.clk, 1)

    # Address 0: JUMP_IF_HIGH, input bit 0, jump to address 2
    await send_instruction(dut, 0x6002)

    # Address 1: WRITE 2
    await send_instruction(dut, 0x1002)

    # Address 2: WRITE 4
    await send_instruction(dut, 0x1004)

    # Exit programming mode.
    # Input bit 0 is HIGH.
    dut.ui_in.value = 1
    await ClockCycles(dut.clk, 1)

    # JUMP_IF_HIGH should jump directly:
    # address 0 -> address 2 -> WRITE 4
    await ClockCycles(dut.clk, 2)

    assert dut.uo_out.value == 4

@cocotb.test()
async def test_jump_instruction(dut):
    dut._log.info("JUMP instruction test")

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Enter programming mode.
    dut.ui_in.value = 4
    await ClockCycles(dut.clk, 1)

    # Address 0: JUMP to address 2
    await send_instruction(dut, 0x5002)

    # Address 1: WRITE 1
    await send_instruction(dut, 0x1001)

    # Address 2: WRITE 4
    await send_instruction(dut, 0x1004)

    # Exit programming mode.
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 1)

    # JUMP should skip address 1 and execute address 2.
    await ClockCycles(dut.clk, 2)

    assert dut.uo_out.value == 4


@cocotb.test()
async def test_read_instruction(dut):
    dut._log.info("READ instruction test")

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Enter programming mode.
    dut.ui_in.value = 4
    await ClockCycles(dut.clk, 1)

    # Address 0: READ GPIO input.
    await send_instruction(dut, 0x2000)

    # Exit programming mode with GPIO input = 0x55.
    dut.ui_in.value = 0x51
    await ClockCycles(dut.clk, 1)

    # Allow READ to execute.
    await ClockCycles(dut.clk, 1)

    assert dut.uo_out.value == 0x51

    @cocotb.test()
async def test_nop_instruction(dut):
    dut._log.info("NOP instruction test")

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Enter programming mode.
    dut.ui_in.value = 4
    await ClockCycles(dut.clk, 1)

    # Address 0: WRITE 7
    await send_instruction(dut, 0x1007)

    # Address 1: NOP
    await send_instruction(dut, 0x0000)

    # Exit programming mode.
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 1)

    # Allow WRITE 7 to execute.
    await ClockCycles(dut.clk, 1)
    assert dut.uo_out.value == 7

    # NOP must leave the output unchanged.
    await ClockCycles(dut.clk, 1)
    assert dut.uo_out.value == 7