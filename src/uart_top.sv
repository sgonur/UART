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
    output logic led_n,      // active-low LED, lit while a byte is being sent
    output logic [5:1] led_o // PMOD 2 debug LEDs, active high
);

    localparam int STRETCH = CLK_FREQ / 10;  // 0.1 s, long enough to see

    // Power-on reset: hold rst high for the first 16 cycles after configuration.
    // The initial value is loaded by the FPGA bitstream, so it is intentional.
    /* verilator lint_off PROCASSINIT */
    logic [3:0] por_cnt = '0;
    /* verilator lint_on PROCASSINIT */
    logic       rst;
    always_ff @(posedge clk)
        if (!(&por_cnt)) por_cnt <= por_cnt + 1'b1;
    assign rst = !(&por_cnt);

    logic [7:0] rx_data;
    logic       rx_valid;
    logic       rx_parity_err;
    logic       tx_ready;

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) u_rx (
        .clk    (clk),
        .rst    (rst),
        .i_rx   (uart_rx),
        .o_data (rx_data),
        .o_valid(rx_valid),
        .o_parity_err(rx_parity_err)   // shown on L5; bytes are echoed regardless
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

    // ---- Debug LEDs (PMOD 2) ----------------------------------------------
    // L1: heartbeat, proves the design is loaded and the clock is running
    logic [23:0] heartbeat;
    always_ff @(posedge clk)
        heartbeat <= heartbeat + 1'b1;
    assign led_o[1] = heartbeat[23];         // ~0.7 Hz at 12 MHz

    // L2: activity on the RX line (synchronised, since uart_rx is async)
    logic [1:0] rx_meta;
    always_ff @(posedge clk)
        rx_meta <= {rx_meta[0], uart_rx};

    pulse_stretch #(.CYCLES(STRETCH)) u_led_rx_line (
        .clk(clk), .i_in(!rx_meta[1]), .o_out(led_o[2])
    );

    // L3: uart_rx received a byte
    pulse_stretch #(.CYCLES(STRETCH)) u_led_rx_valid (
        .clk(clk), .i_in(rx_valid), .o_out(led_o[3])
    );

    // L4: uart_tx is sending
    pulse_stretch #(.CYCLES(STRETCH)) u_led_tx_busy (
        .clk(clk), .i_in(!tx_ready), .o_out(led_o[4])
    );

    // L5: a parity error has been seen (stays on until reset)
    always_ff @(posedge clk)
        if (rst)                led_o[5] <= 1'b0;
        else if (rx_parity_err) led_o[5] <= 1'b1;

endmodule

`default_nettype wire
