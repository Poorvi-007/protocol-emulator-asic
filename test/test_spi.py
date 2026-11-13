import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer


async def send_bit(dut, bit_value):
    dut.ui_in.value = ((bit_value & 1) << 0) | (1 << 1) | (1 << 2)
    await ClockCycles(dut.clk, 1)

    dut.ui_in.value = 4
    await ClockCycles(dut.clk, 1)


async def send_instruction(dut, instruction):
    for bit_index in range(15, -1, -1):
        await send_bit(dut, (instruction >> bit_index) & 1)


@cocotb.test()
async def test_spi_top_level_integration(dut):

    dut._log.info("Starting SPI top-level integration test")

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0x10
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Enter programming mode.
    dut.ui_in.value = 4
    await ClockCycles(dut.clk, 2)

    # Address 0: SPI divider = 0
    await send_instruction(dut, 0xC400)

    # Address 1: SPI transmit data = A5
    await send_instruction(dut, 0xCDA5)

    # Address 2: SPI control: mode 0, start transfer
    await send_instruction(dut, 0xCF01)

    # Address 3: NOP
    await send_instruction(dut, 0x0000)

    # Address 4: Read SPI RX data register
    await send_instruction(dut, 0xDE00)

    # Exit programming mode and execute.
    dut.ui_in.value = 0

    # MISO is held HIGH, so expected received data is FF.
    captured_mosi = []
    previous_sclk = 0
    saw_chip_select = False

    for cycle in range(1000):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

        pins = int(dut.uio_out.value)
        sclk = (pins >> 2) & 1
        mosi = (pins >> 3) & 1
        cs_n = (pins >> 5) & 1

        if cs_n == 0:
            saw_chip_select = True

        if cs_n == 0 and previous_sclk == 0 and sclk == 1:
            captured_mosi.append(mosi)

        previous_sclk = sclk

    # Pause processor after the transfer and RX register read.
    dut.ui_in.value = 4
    await ClockCycles(dut.clk, 2)

    # Check pin directions.
    assert int(dut.uio_oe.value) == 0x2E

    # Check chip-select was activated.
    assert saw_chip_select, "SPI chip-select was never activated"

    # Check all eight MOSI bits.
    assert captured_mosi[:8] == [
        1, 0, 1, 0, 0, 1, 0, 1
    ], f"Unexpected MOSI data: {captured_mosi}"

    # Check received data.
    received = int(dut.uo_out.value)
    assert received == 0xFF, (
        f"Expected SPI RX data FF, got {received:02X}"
    )

    dut._log.info("SPI top-level integration test PASSED")
