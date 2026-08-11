# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_counter_up(dut):
    dut._log.info("Start counter up test")

    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    assert dut.uo_out.value == 0, f"Expected count to reset to 0, got {dut.uo_out.value}"

    # Enable counting, count up (ui_in[0]=1, ui_in[1]=0)
    dut.ui_in.value = 0b00000001
    await ClockCycles(dut.clk, 1)

    for expected in range(1, 6):
        await ClockCycles(dut.clk, 1)
        assert dut.uo_out.value == expected, f"Expected {expected}, got {dut.uo_out.value}"

    dut._log.info("Counter up test completed successfully")


@cocotb.test()
async def test_counter_down(dut):
    dut._log.info("Start counter down test")

    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # Count up a few times first so we have something to count down from
    dut.ui_in.value = 0b00000001
    await ClockCycles(dut.clk, 5)
    assert dut.uo_out.value == 5, f"Expected 5, got {dut.uo_out.value}"

    # Switch to count down (ui_in[0]=1, ui_in[1]=1)
    dut.ui_in.value = 0b00000011
    await ClockCycles(dut.clk, 1)

    for expected in [4, 3, 2, 1, 0]:
        await ClockCycles(dut.clk, 1)
        assert dut.uo_out.value == expected, f"Expected {expected}, got {dut.uo_out.value}"

    dut._log.info("Counter down test completed successfully")


@cocotb.test()
async def test_counter_disabled(dut):
    dut._log.info("Start counter disabled test")

    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # enable = 0, so counter should stay at 0
    dut.ui_in.value = 0b00000000
    await ClockCycles(dut.clk, 10)
    assert dut.uo_out.value == 0, f"Expected count to stay 0, got {dut.uo_out.value}"

    dut._log.info("Counter disabled test completed successfully")
