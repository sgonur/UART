// Board top level: echoes every byte received on the UART back to the host.
// Pin mapping lives in constraints/<board>.pcf.

`default_nettype none

module uart_top #(
    parameter int CLK_FREQ = 12_000_000,
    parameter int BAUD     = 115_200
) (
    input  logic clk,
    input  logic uart_rx,
    output logic uart_tx,
    output logic led_n       // active-low LED, lit while a byte is being sent
);

    // Power-on reset: hold rst high for the first 16 cycles after configuration.
    logic [3:0] por_cnt = '0;
    logic       rst;
    always_ff @(posedge clk)
        if (!(&por_cnt)) por_cnt <= por_cnt + 1'b1;
    assign rst = !(&por_cnt);

    logic [7:0] rx_data;
    logic       rx_valid;
    logic       tx_ready;

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) u_rx (
        .clk    (clk),
        .rst    (rst),
        .i_rx   (uart_rx),
        .o_data (rx_data),
        .o_valid(rx_valid),
        .o_parity_err()
    );

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) u_tx (
        .clk    (clk),
        .rst    (rst),
        .i_data (rx_data),
        .i_valid(rx_valid && tx_ready),
        .o_ready(tx_ready),
        .o_tx   (uart_tx)
    );

    assign led_n = tx_ready;

endmodule

`default_nettype wire
