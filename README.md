# UART

A UART transmitter and receiver (8E1) in SystemVerilog, verified with
[cocotb](https://www.cocotb.org/) and built for Lattice iCE40 using the
[OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build).

## Layout

```
src/            RTL (uart_tx, uart_rx, uart_top)
tb/             cocotb testbenches + pytest runner
constraints/    Pin constraint files (.pcf) per board
docs/           Specification and design notes
scripts/        Helper scripts
build/          Generated outputs (git-ignored)
```

## Setup

1. Install the [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build/releases)
   and put it on your `PATH`:

   ```sh
   source /path/to/oss-cad-suite/environment
   ```

   This provides `yosys`, `nextpnr-ice40`, `icepack`, `iceprog`, `iverilog`,
   `verilator` and `gtkwave`.

2. Create the Python virtual environment:

   ```sh
   make venv
   source .venv/bin/activate   # optional, the Makefile uses .venv directly
   ```

## Usage

| Command                   | What it does                                  |
|---------------------------|-----------------------------------------------|
| `make test`               | Run all cocotb tests with Icarus Verilog      |
| `make test SIM=verilator` | Run tests with Verilator                      |
| `make test WAVES=1`       | Also dump waveforms into `build/sim/<module>` |
| `make lint`               | Verilator lint of the RTL                     |
| `make synth`              | Yosys synthesis                               |
| `make bit`                | Synthesis, place & route and bitstream        |
| `make prog`               | Flash the board                               |
| `make clean`              | Delete build outputs                          |

The default target is the iCEBreaker (iCE40UP5K). For another iCE40 board, add
a `.pcf` file in `constraints/` and override the variables:

```sh
make bit BOARD=myboard DEVICE=hx8k PACKAGE=ct256 CLK_MHZ=12
```

## Testing on hardware

`uart_top` echoes back every byte it receives. After `make prog`, open the
board's serial port at 115200 8E1 and type:

```sh
screen /dev/tty.usbserial-*1 115200,cs8,parenb,-parodd,-cstopb
```

See [docs/spec.md](docs/spec.md) for the interface specification.
