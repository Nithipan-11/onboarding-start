# SPDX-FileCopyrightText: (c) 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.types import LogicArray


def ui_in_logicarray(ncs, bit, sclk):
    return LogicArray(f"00000{ncs}{bit}{sclk}")


async def await_half_sclk(dut):
    start_time = cocotb.utils.get_sim_time(units="ns")
    while True:
        await ClockCycles(dut.clk, 1)
        if (start_time + 100 * 100 * 0.5) < cocotb.utils.get_sim_time(units="ns"):
            break
    return


async def send_spi_transaction(dut, r_w, address, data):
    if isinstance(data, LogicArray):
        data_int = int(data)
    else:
        data_int = data
    if address < 0 or address > 127:
        raise ValueError("Address must be 7-bit (0-127)")
    if data_int < 0 or data_int > 255:
        raise ValueError("Data must be 8-bit (0-255)")

    first_byte = (int(r_w) << 7) | address
    sclk = 0
    ncs = 0
    bit = 0
    dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)
    await ClockCycles(dut.clk, 1)

    for i in range(8):
        bit = (first_byte >> (7 - i)) & 0x1
        sclk = 0
        dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)
        await await_half_sclk(dut)
        sclk = 1
        dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)
        await await_half_sclk(dut)

    for i in range(8):
        bit = (data_int >> (7 - i)) & 0x1
        sclk = 0
        dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)
        await await_half_sclk(dut)
        sclk = 1
        dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)
        await await_half_sclk(dut)

    sclk = 0
    ncs = 1
    bit = 0
    dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)
    await ClockCycles(dut.clk, 600)
    return ui_in_logicarray(ncs, bit, sclk)


@cocotb.test()
async def test_spi(dut):
    dut._log.info("Start SPI test")

    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    dut._log.info("Reset")
    dut.ena.value = 1
    ncs, bit, sclk = 1, 0, 0
    dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    dut._log.info("Write transaction, address 0x00, data 0xF0")
    await send_spi_transaction(dut, 1, 0x00, 0xF0)
    assert dut.uo_out.value == 0xF0, f"Expected 0xF0, got {dut.uo_out.value}"
    await ClockCycles(dut.clk, 1000)

    dut._log.info("Write transaction, address 0x01, data 0xCC")
    await send_spi_transaction(dut, 1, 0x01, 0xCC)
    assert dut.uio_out.value == 0xCC, f"Expected 0xCC, got {dut.uio_out.value}"
    await ClockCycles(dut.clk, 100)

    dut._log.info("Write transaction, address 0x30 (invalid), data 0xAA")
    await send_spi_transaction(dut, 1, 0x30, 0xAA)
    await ClockCycles(dut.clk, 100)

    dut._log.info("Read transaction (invalid), address 0x30, data 0xBE")
    await send_spi_transaction(dut, 0, 0x30, 0xBE)
    assert dut.uo_out.value == 0xF0, f"Expected 0xF0, got {dut.uo_out.value}"
    await ClockCycles(dut.clk, 100)

    dut._log.info("Read transaction (invalid), address 0x41, data 0xEF")
    await send_spi_transaction(dut, 0, 0x41, 0xEF)
    await ClockCycles(dut.clk, 100)

    dut._log.info("Write transaction, address 0x02, data 0xFF")
    await send_spi_transaction(dut, 1, 0x02, 0xFF)
    await ClockCycles(dut.clk, 100)

    dut._log.info("Write transaction, address 0x04, data 0xCF")
    await send_spi_transaction(dut, 1, 0x04, 0xCF)
    await ClockCycles(dut.clk, 30000)

    dut._log.info("Write transaction, address 0x04, data 0xFF")
    await send_spi_transaction(dut, 1, 0x04, 0xFF)
    await ClockCycles(dut.clk, 30000)

    dut._log.info("Write transaction, address 0x04, data 0x00")
    await send_spi_transaction(dut, 1, 0x04, 0x00)
    await ClockCycles(dut.clk, 30000)

    dut._log.info("Write transaction, address 0x04, data 0x01")
    await send_spi_transaction(dut, 1, 0x04, 0x01)
    await ClockCycles(dut.clk, 30000)

    dut._log.info("SPI test completed successfully")


@cocotb.test()
async def test_pwm_freq(dut):
    dut._log.info("Start PWM frequency test")

    clock = Clock(dut.clk, 100, units="ns")  # 10 MHz
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = ui_in_logicarray(1, 0, 0)
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    await send_spi_transaction(dut, 1, 0x00, 0x01)
    await send_spi_transaction(dut, 1, 0x02, 0x01)
    await send_spi_transaction(dut, 1, 0x04, 0x80)

    prev = int(dut.uo_out.value) & 1
    edge_times = []
    timeout = 0
    while len(edge_times) < 3 and timeout < 20000:
        await ClockCycles(dut.clk, 1)
        cur = int(dut.uo_out.value) & 1
        if prev == 0 and cur == 1:
            edge_times.append(cocotb.utils.get_sim_time(units="ns"))
        prev = cur
        timeout += 1

    assert len(edge_times) >= 2, "Did not observe enough PWM rising edges"
    period_ns = edge_times[1] - edge_times[0]
    freq_hz = 1e9 / period_ns
    dut._log.info(f"Measured PWM frequency: {freq_hz:.1f} Hz")
    assert 2970 <= freq_hz <= 3030, f"Expected 2970-3030 Hz, got {freq_hz:.1f} Hz"

    dut._log.info("PWM Frequency test completed successfully")


@cocotb.test()
async def test_pwm_duty(dut):
    dut._log.info("Start PWM Duty Cycle test")

    clock = Clock(dut.clk, 100, units="ns")  # 10 MHz
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = ui_in_logicarray(1, 0, 0)
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    await send_spi_transaction(dut, 1, 0x00, 0x01)
    await send_spi_transaction(dut, 1, 0x02, 0x01)

    for duty in [0x00, 0x40, 0x80, 0xC0, 0xFF]:
        await send_spi_transaction(dut, 1, 0x04, duty)
        await ClockCycles(dut.clk, 3334 * 2)

        expected_duty = duty / 256

        if duty == 0x00:
            await ClockCycles(dut.clk, 3334)
            assert int(dut.uo_out.value) & 1 == 0, "Expected output low for 0x00 duty"
            dut._log.info(f"Duty {duty:#04x}: confirmed always low")
            continue

        if duty == 0xFF:
            await ClockCycles(dut.clk, 3334)
            assert int(dut.uo_out.value) & 1 == 1, "Expected output high for 0xFF duty"
            dut._log.info(f"Duty {duty:#04x}: confirmed always high")
            continue

        prev = int(dut.uo_out.value) & 1
        while True:
            await ClockCycles(dut.clk, 1)
            cur = int(dut.uo_out.value) & 1
            if prev == 0 and cur == 1:
                rising_time = cocotb.utils.get_sim_time(units="ns")
                break
            prev = cur

        prev = cur
        while True:
            await ClockCycles(dut.clk, 1)
            cur = int(dut.uo_out.value) & 1
            if prev == 1 and cur == 0:
                falling_time = cocotb.utils.get_sim_time(units="ns")
                break
            prev = cur

        prev = cur
        while True:
            await ClockCycles(dut.clk, 1)
            cur = int(dut.uo_out.value) & 1
            if prev == 0 and cur == 1:
                next_rising_time = cocotb.utils.get_sim_time(units="ns")
                break
            prev = cur

        high_time = falling_time - rising_time
        period = next_rising_time - rising_time
        measured_duty = high_time / period

        dut._log.info(
            f"Duty {duty:#04x}: expected {expected_duty*100:.1f}%, "
            f"measured {measured_duty*100:.1f}%"
        )
        assert abs(measured_duty - expected_duty) < 0.05, (
            f"Duty cycle {duty:#04x}: expected ~{expected_duty*100:.1f}%, "
            f"got {measured_duty*100:.1f}%"
        )

    dut._log.info("PWM Duty Cycle test completed successfully")