// UART receiver: 8 data bits, even parity, 1 stop bit (8E1), LSB first.
//
// o_valid pulses high for one cycle when a complete byte is on o_data.
// o_parity_err is high during that same cycle if the parity bit was wrong
// (the byte is still delivered).

`default_nettype none

module uart_rx #(
    parameter int CLK_FREQ = 12_000_000,
    parameter int BAUD     = 115_200
) (
    input  logic       clk,
    input  logic       rst,      // synchronous, active high

    input  logic       i_rx,     // serial line, idles high (asynchronous)

    output logic [7:0] o_data,
    output logic       o_valid,
    output logic       o_parity_err
);

    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD;

    // TODO: implement the receiver.
    //   - synchronise i_rx into the clk domain (2-flop synchroniser)
    //   - detect the falling edge of the start bit
    //   - sample each data bit in the middle of its bit period
    //   - sample the parity bit and compare against ^data (even parity)
    //   - check the stop bit, then pulse o_valid with the received byte
    //     and o_parity_err if the parity didn't match
    assign o_data       = 8'h00;
    assign o_valid      = 1'b0;
    assign o_parity_err = 1'b0;

endmodule

`default_nettype wire
