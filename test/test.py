# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # Test the first programmed WRITE instruction
    await ClockCycles(dut.clk, 2)
    assert dut.uo_out.value == 1

    # Test the second programmed WRITE instruction
    await ClockCycles(dut.clk, 1)
    assert dut.uo_out.value == 2

    # Test the third programmed WRITE instruction
    await ClockCycles(dut.clk, 1)
    assert dut.uo_out.value == 4


    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.
