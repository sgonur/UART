"""pytest entry point: builds each DUT and runs its cocotb test module.

Usage:
    pytest tb/                         # all tests, Icarus
    SIM=verilator pytest tb/           # use Verilator instead
    WAVES=1 pytest tb/ -k tx           # dump waveforms for uart_tx
"""

import os
from pathlib import Path

import pytest
from cocotb_tools.runner import get_runner

from uart_params import BAUD, CLK_FREQ

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
TB = ROOT / "tb"
BUILD = ROOT / "build" / "sim"

SIM = os.getenv("SIM", "icarus")
WAVES = os.getenv("WAVES", "0") == "1"


@pytest.mark.parametrize(
    "toplevel, test_module",
    [
        ("uart_tx", "uart_tx_tests"),
        ("uart_rx", "uart_rx_tests"),
    ],
)
def test_uart(toplevel, test_module):
    runner = get_runner(SIM)
    build_dir = BUILD / toplevel
    runner.build(
        sources=[SRC / f"{toplevel}.sv"],
        hdl_toplevel=toplevel,
        parameters={"CLK_FREQ": CLK_FREQ, "BAUD": BAUD},
        timescale=("1ns", "1ps"),
        build_dir=build_dir,
        waves=WAVES,
        always=True,
    )
    runner.test(
        hdl_toplevel=toplevel,
        test_module=test_module,
        test_dir=TB,
        build_dir=build_dir,
        waves=WAVES,
    )
