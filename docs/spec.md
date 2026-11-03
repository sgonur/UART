# UART Specification

## Frame format

8E1: one start bit (`0`), 8 data bits LSB first, one even parity bit, one
stop bit (`1`). The line idles high. 11 bit periods per frame.

```
 idle  start  d0  d1  d2  d3  d4  d5  d6  d7  par  stop  idle
 ‾‾‾‾‾‾\____/‾‾‾X‾‾‾X‾‾‾X‾‾‾X‾‾‾X‾‾‾X‾‾‾X‾‾‾X‾‾‾\‾‾‾‾‾‾‾‾‾‾‾‾
```

Even parity: `par = ^data`, so the count of 1s across d0–d7 and `par` is even.

Each bit lasts `CLKS_PER_BIT = CLK_FREQ / BAUD` clock cycles
(12 MHz / 115200 ≈ 104).

## Parameters

| Name       | Default      | Description            |
|------------|--------------|------------------------|
| `CLK_FREQ` | `12_000_000` | System clock in Hz     |
| `BAUD`     | `115_200`    | Baud rate in bits/s    |

## `uart_tx`

| Port      | Dir | Width | Description                                   |
|-----------|-----|-------|-----------------------------------------------|
| `clk`     | in  | 1     | System clock                                  |
| `rst`     | in  | 1     | Synchronous reset, active high                |
| `i_data`  | in  | 8     | Byte to send                                  |
| `i_valid` | in  | 1     | Start a frame with `i_data` (when `o_ready`)  |
| `o_ready` | out | 1     | High when idle and able to accept a byte      |
| `o_tx`    | out | 1     | Serial output                                 |

## `uart_rx`

| Port      | Dir | Width | Description                                   |
|-----------|-----|-------|-----------------------------------------------|
| `clk`     | in  | 1     | System clock                                  |
| `rst`     | in  | 1     | Synchronous reset, active high                |
| `i_rx`    | in  | 1     | Serial input (asynchronous, must synchronise) |
| `o_data`  | out | 8     | Received byte                                 |
| `o_valid` | out | 1     | One-cycle pulse when `o_data` is valid        |
| `o_parity_err` | out | 1 | High with `o_valid` if the parity bit was wrong |

The receiver should sample each bit in the middle of its bit period and
discard frames with a bad stop bit. A parity mismatch does not drop the byte;
it is delivered with `o_parity_err` set.

## `uart_top`

Board-level echo: every byte received is sent straight back. A red LED lights
while the transmitter is busy. Pins are in `constraints/icebreaker.pcf`.
