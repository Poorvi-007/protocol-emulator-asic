# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

async def load_instruction(dut, instruction):
    for i in range(15, -1, -1):
        dut.ui_in.value = (1 << 0) | (1 << 2) | (((instruction >> i) & 1) << 0) | (1 << 1)
        await ClockCycles(dut.clk, 1)
        dut.ui_in.value = 0
        await ClockCycles(dut.clk, 1)

async def send_instruction(dut, instruction):
    for i in range(15, -1, -1):
        await send_bit(dut, (instruction >> i) & 1)

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

    # Enter programming mode
    dut.ui_in.value = 4

    # Program 0: WRITE 1
    await send_instruction(dut, 0x1001)

    # Program 1: WAIT 3 cycles
    await send_instruction(dut, 0x3003)

    # Program 2: WRITE 4
    await send_instruction(dut, 0x1004)

    # Return to normal execution mode
    dut.ui_in.value = 0

    # Allow the first instruction to execute
    await ClockCycles(dut.clk, 2)
    assert dut.uo_out.value == 1

    # WAIT should keep the output at 1
    await ClockCycles(dut.clk, 3)
    assert dut.uo_out.value == 1

        # WAIT should finish and execute WRITE 4
    await ClockCycles(dut.clk, 2)
    assert dut.uo_out.value == 4


    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.

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

    await ClockCycles(dut.clk, 2)

    assert dut.uo_out.value == 1

    await ClockCycles(dut.clk, 1)

    assert dut.uo_out.value == 2

    