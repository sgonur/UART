"""cocotb tests for uart_rx."""

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer, with_timeout

from uart_params import CLK_PERIOD_NS, CLKS_PER_BIT, parity

FRAME_TIMEOUT_NS = 2 * CLKS_PER_BIT * CLK_PERIOD_NS


async def reset(dut):
    dut.i_rx.value = 1
    dut.rst.value = 1
    await ClockCycles(dut.clk, 5)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def drive_frame(dut, byte, bad_parity=False, stop_bit=1):
    """Drive one 8E1 frame onto i_rx."""
    bit_time = CLKS_PER_BIT * CLK_PERIOD_NS
    par = parity(byte) ^ bad_parity
    bits = [0] + [(byte >> i) & 1 for i in range(8)] + [par, stop_bit]
    for bit in bits:
        dut.i_rx.value = bit
        await Timer(bit_time, "ns")
    dut.i_rx.value = 1


async def wait_valid(dut):
    """Return (data, parity_err) from the next o_valid pulse."""
    while True:
        await RisingEdge(dut.clk)
        if dut.o_valid.value:
            return int(dut.o_data.value), int(dut.o_parity_err.value)


@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_idle(dut):
    """No o_valid pulses while the line is idle."""
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, "ns").start())
    await reset(dut)
    for _ in range(20 * CLKS_PER_BIT):
        await RisingEdge(dut.clk)
        assert dut.o_valid.value == 0


@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_single_byte(dut):
    """One frame is received and reported on o_data."""
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, "ns").start())
    await reset(dut)
    got = cocotb.start_soon(wait_valid(dut))
    await drive_frame(dut, 0x3C)
    assert await with_timeout(got, FRAME_TIMEOUT_NS, "ns") == (0x3C, 0)


@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_random_bytes(dut):
    """Back-to-back random frames are all received correctly."""
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, "ns").start())
    await reset(dut)
    data = [random.randrange(256) for _ in range(20)]
    for byte in data:
        got = cocotb.start_soon(wait_valid(dut))
        await drive_frame(dut, byte)
        assert await with_timeout(got, FRAME_TIMEOUT_NS, "ns") == (byte, 0)


@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_parity_error(dut):
    """A frame with a flipped parity bit is delivered with o_parity_err set."""
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, "ns").start())
    await reset(dut)
    for byte in (0x00, 0x01, 0xA5, 0xFF):
        got = cocotb.start_soon(wait_valid(dut))
        await drive_frame(dut, byte, bad_parity=True)
        assert await with_timeout(got, FRAME_TIMEOUT_NS, "ns") == (byte, 1)
