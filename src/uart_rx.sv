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
    localparam int CNT_W                  = $clog2(CLKS_PER_BIT);
    localparam logic [CNT_W-1:0] BAUD_MAX = CNT_W'(CLKS_PER_BIT - 1);  // Full Period
    localparam logic [CNT_W-1:0] HALF     = CNT_W'(CLKS_PER_BIT / 2 - 1);  // Half Period

    logic baud_tick, mid_tick, ff1_irx, rx_sync;
    logic [7:0] shift_reg;
    logic parity_err;
    logic [2:0] bit_idx;
    logic [CNT_W-1:0] baud_cnt;

    assign baud_tick = (baud_cnt == BAUD_MAX);

    // Pass i_rx through a 2-flop synchronizer
    always_ff @(posedge clk) begin
        if (rst) begin
            ff1_irx <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            ff1_irx <= i_rx;
            rx_sync <= ff1_irx;
        end
    end

    // 5 State Receiver state machine
    typedef enum logic [4:0] {  
        IDLE   = 5'b00001,
        START  = 5'b00010,
        DATA   = 5'b00100,
        PARITY = 5'b01000,
        STOP   = 5'b10000
    } state_t;

    state_t state, next_state;

    // Middle of the start bit
    assign mid_tick = (state == START) && (baud_cnt == HALF);

    // LSB to MSB
    always_ff @(posedge clk) begin
        if (state == DATA && baud_tick)
            shift_reg <= {rx_sync, shift_reg[7:1]};
    end

    // Parity check: data bits + parity bit must have an even number of 1s
    always_ff @(posedge clk) begin
        if (state == PARITY && baud_tick)
            parity_err <= (^shift_reg) ^ rx_sync;
    end

    // Data bit counter
    always_ff @(posedge clk) begin
        if (state != DATA)
            bit_idx <= '0;
        else if (baud_tick)
            bit_idx <= bit_idx + 1'b1;
    end

    // baud_cnt calculation
    always_ff @(posedge clk) begin
        if (rst || state == IDLE || baud_tick || mid_tick)
            baud_cnt <= '0;
        else
            baud_cnt <= baud_cnt + 1'b1;
    end


    // State Register
    always_ff @(posedge clk ) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE:   if (~rx_sync)   next_state                    = START;
            START:  if (rx_sync)    next_state                    = IDLE;    // false start (glitch)
                    else if (mid_tick) next_state                 = DATA;
            DATA:   if (baud_tick && bit_idx == 3'd7) next_state  = PARITY;  // advance to next state once all 8 bits of data are transfered
            PARITY: if (baud_tick) next_state                     = STOP;
            STOP:   if (baud_tick) next_state                     = IDLE;
            default:               next_state                     = IDLE;
        endcase
    end

    assign o_data       = shift_reg;
    assign o_valid      = (state == STOP) && baud_tick && rx_sync;
    assign o_parity_err = o_valid && parity_err;

endmodule

`default_nettype wire
