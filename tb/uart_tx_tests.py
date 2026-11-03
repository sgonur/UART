"""cocotb tests for uart_tx."""

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer

from uart_params import CLK_PERIOD_NS, CLKS_PER_BIT, parity


async def reset(dut):
    dut.i_data.value = 0
    dut.i_valid.value = 0
    dut.rst.value = 1
    await ClockCycles(dut.clk, 5)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def send(dut, byte):
    """Present one byte on the input handshake."""
    while not dut.o_ready.value:
        await RisingEdge(dut.clk)
    dut.i_data.value = byte
    dut.i_valid.value = 1
    await RisingEdge(dut.clk)
    dut.i_valid.value = 0


async def capture_frame(dut):
    """Wait for a start bit on o_tx and return the decoded byte."""
    bit_time = CLKS_PER_BIT * CLK_PERIOD_NS
    await FallingEdge(dut.o_tx)
    await Timer(bit_time // 2, "ns")  # middle of start bit
    assert dut.o_tx.value == 0, "start bit glitch"
    byte = 0
    for i in range(8):
        await Timer(bit_time, "ns")
        byte |= int(dut.o_tx.value) << i
    await Timer(bit_time, "ns")
    assert dut.o_tx.value == parity(byte), "wrong parity bit"
    await Timer(bit_time, "ns")
    assert dut.o_tx.value == 1, "missing stop bit"
    return byte


@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_idle(dut):
    """After reset the line idles high and the transmitter is ready."""
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, "ns").start())
    await reset(dut)
    await ClockCycles(dut.clk, 3 * CLKS_PER_BIT)
    assert dut.o_tx.value == 1
    assert dut.o_ready.value == 1


@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_single_byte(dut):
    """One byte is serialised as 8E1, LSB first."""
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, "ns").start())
    await reset(dut)
    rx = cocotb.start_soon(capture_frame(dut))
    await send(dut, 0xA5)
    assert await rx == 0xA5


@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_random_bytes(dut):
    """Back-to-back random bytes are all transmitted correctly."""
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, "ns").start())
    await reset(dut)
    data = [random.randrange(256) for _ in range(20)]
    for byte in data:
        rx = cocotb.start_soon(capture_frame(dut))
        await send(dut, byte)
        assert await rx == byte
