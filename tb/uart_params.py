"""Simulation parameters shared by the test runner and the cocotb tests.

A small clock/baud ratio keeps simulations fast; CLKS_PER_BIT = 10.
"""

CLK_FREQ = 1_000_000
BAUD = 100_000
CLKS_PER_BIT = CLK_FREQ // BAUD
CLK_PERIOD_NS = 1_000_000_000 // CLK_FREQ


def parity(byte):
    """Even parity bit: makes the number of 1s in data + parity even."""
    return bin(byte).count("1") & 1
