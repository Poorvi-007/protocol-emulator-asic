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
    
