// Stretches a short pulse so it is visible on an LED: o_out stays high for
// CYCLES clock cycles after the last cycle i_in was high.

`default_nettype none

module pulse_stretch #(
    parameter int CYCLES = 1_200_000     // 0.1 s at 12 MHz
) (
    input  logic clk,
    input  logic i_in,
    output logic o_out
);

    localparam int CNT_W = $clog2(CYCLES + 1);
    localparam logic [CNT_W-1:0] LOAD = CNT_W'(CYCLES);

    logic [CNT_W-1:0] cnt;

    always_ff @(posedge clk) begin
        if (i_in)
            cnt <= LOAD;
        else if (cnt != '0)
            cnt <= cnt - 1'b1;
    end

    assign o_out = (cnt != '0);

endmodule

`default_nettype wire
