`timescale 1ns / 100ps

module testbench();

reg clk = 0;
always #8 clk = ~clk;

wire scl, sda;

top fpga(
    .clk(clk),
    .led(0),
    .ac_scl(scl),
    .ac_sda(sda)
    );

PULLUP p0(.O(scl));
PULLUP p1(.O(sda));

endmodule
