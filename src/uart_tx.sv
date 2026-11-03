// UART transmitter: 8 data bits, even parity, 1 stop bit (8E1), LSB first.
//
// Handshake: when o_ready is high, pulse i_valid for one cycle with i_data
// to start a frame. o_ready drops until the stop bit has been sent.

`default_nettype none

module uart_tx #(
    parameter int CLK_FREQ = 12_000_000,
    parameter int BAUD     = 115_200
) (
    input  logic       clk,
    input  logic       rst,      // synchronous, active high

    input  logic [7:0] i_data,
    input  logic       i_valid,
    output logic       o_ready,

    output logic       o_tx      // serial line, idles high
);

    localparam int CLKS_PER_BIT           = CLK_FREQ / BAUD;
    localparam int CNT_W                  = $clog2(CLKS_PER_BIT);
    localparam logic [CNT_W-1:0] BAUD_MAX = CNT_W'(CLKS_PER_BIT - 1);

    logic baud_tick;
    logic [7:0] shift_reg;
    logic parity_bit;
    logic [2:0] bit_idx;
    logic [CNT_W-1:0] baud_cnt;

    assign baud_tick = (baud_cnt == BAUD_MAX);

    // 5 State Transimitter state machine
    typedef enum logic [4:0] {  
        IDLE   = 5'b00001,
        START  = 5'b00010,
        DATA   = 5'b00100,
        PARITY = 5'b01000,
        STOP   = 5'b10000
    } state_t;

    state_t state, next_state;

    // Shift register logic (parity is computed here, before the data shifts out)
    always_ff @(posedge clk) begin
        if (state == IDLE && i_valid) begin
            shift_reg  <= i_data;
            parity_bit <= ^i_data; // Tells if the byte has an odd number of 1s
        end else if (state == DATA && baud_tick) begin
            shift_reg  <= {1'b0, shift_reg[7:1]};
        end
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
        if (rst || state == IDLE || baud_tick)
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
            IDLE:   if (i_valid)   next_state                    = START;
            START:  if (baud_tick) next_state                    = DATA;
            DATA:   if (baud_tick && bit_idx == 3'd7) next_state = PARITY;  // advance to next state once all 8 bits of data are transfered
            PARITY: if (baud_tick) next_state                    = STOP;
            STOP:   if (baud_tick) next_state                    = IDLE;
            default:               next_state                    = IDLE;
        endcase
    end

    // Outputs
    always_comb begin
        o_ready = (state == IDLE);
        case (state)
            IDLE: begin
                o_tx = 1'b1;
            end
            START: begin
                o_tx = 1'b0;
            end
            DATA: begin
                o_tx = shift_reg[0];
            end
            PARITY: begin
                o_tx = parity_bit;
            end
            STOP: begin
                o_tx = 1'b1;
            end
            default: begin
                o_tx = 1'b1;
            end
        endcase
    end



endmodule

`default_nettype wire
