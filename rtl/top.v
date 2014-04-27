/* Copyright 2014 Brian Swetland <swetland@frotz.net>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

`timescale 1ns / 100ps

module top(
	input clk,
	output [3:0] led,
	inout ac_scl,
	inout ac_sda
	);

// power on reset
reg [3:0]resets = 4'b1111;
always @(posedge clk)
	resets <= { resets[2:0], 1'b0 };
wire reset = resets[3];

// jtag debugport
wire [31:0]dprdata;
wire dprvalid;
wire [31:0]dpwdata;

// i2c signals from i2c core to pads
wire scl_pad_i;
wire scl_pad_o;
wire scl_padoen_o;

wire sda_pad_i;
wire sda_pad_o;
wire sda_padoen_o;

IOBUF iobuf_scl(
    .O(scl_pad_i),
    .I(scl_pad_o),
    .T(scl_padoen_o),
    .IO(ac_scl)
    );

IOBUF iobuf_sda(
    .O(sda_pad_i),
    .I(sda_pad_o),
    .T(sda_padoen_o),
    .IO(ac_sda)
    );

// debugging - route the signal observed at the pad and driven
// to header that can be probed 
//assign jb[0] = scl_pad_i;
//assign jb[1] = sda_pad_i;
//assign jb[2] = scl_padoen_o;
//assign jb[3] = sda_padoen_o;

// commands to i2c core
reg cmd_start = 0;
reg cmd_stop = 0;
reg cmd_rd = 0;
reg cmd_wr = 0;
reg cmd_ack = 0;
reg [7:0]txdata;

// status from i2c core, registered on +clk
reg sts_arb_lost = 0;
reg sts_rxack = 0;
reg sts_tip = 0;

// i2c_* state from i2c, observed on +clk
wire i2c_cmd_ack;
wire i2c_rx_ack;
wire i2c_busy;
wire i2c_arb_lost;
wire [7:0]i2c_rxdata;

// update i2c commands on reset or +clk
always @(posedge clk) begin
	if (reset) begin
		cmd_start <= 1'b0;
		cmd_stop <= 1'b0;
		cmd_rd <= 1'b0;
		cmd_wr <= 1'b0;
	end else if (i2c_cmd_ack | i2c_arb_lost) begin
		cmd_start <= 1'b0;
		cmd_stop <= 1'b0;
		cmd_rd <= 1'b0;
		cmd_wr <= 1'b0;
	end else if (dprvalid) begin
		// register command from jtag debugport
		cmd_ack <= dprdata[12];
		cmd_rd <= dprdata[11];
		cmd_wr <= dprdata[10];
		cmd_stop <= dprdata[9];
		cmd_start <= dprdata[8];
		txdata <= dprdata[7:0];
	end
end

assign dpwdata[31:16] = 0;
assign dpwdata[15] = i2c_busy;
assign dpwdata[14] = sts_arb_lost;
assign dpwdata[13] = sts_rxack;
assign dpwdata[12] = sts_tip;
assign dpwdata[11] = cmd_rd;
assign dpwdata[10] = cmd_wr;
assign dpwdata[9] = cmd_stop;
assign dpwdata[8] = cmd_start;
assign dpwdata[7:0] = i2c_rxdata;

// update registered i2c status on reset or +clk
always @(posedge clk) begin
	if (reset) begin
		sts_arb_lost <= 1'b0;
		sts_rxack <= 1'b0;
		sts_tip <= 1'b0;
	end else begin
		sts_arb_lost <= i2c_arb_lost | (i2c_arb_lost & ~cmd_start);
		sts_rxack <= i2c_rx_ack;
		sts_tip <= (cmd_rd | cmd_wr);
	end
end

i2c_master_byte_ctrl i2c_core (
	.clk(clk),
	.rst(reset),
	.nReset(~reset),
	.ena(1'b1),
	.clk_cnt(16'd249),
	.start(cmd_start),
	.stop(cmd_stop),
	.read(cmd_rd),
	.write(cmd_wr),
	.ack_in(cmd_ack),
	.din(txdata),
	.cmd_ack(i2c_cmd_ack),
	.ack_out(i2c_rx_ack),
	.dout(i2c_rxdata),
	.i2c_busy(i2c_busy),
	.i2c_al(i2c_arb_lost),
	.scl_i(scl_pad_i),
	.scl_o(scl_pad_o),
	.scl_oen(scl_padoen_o),
	.sda_i(sda_pad_i),
	.sda_o(sda_pad_o),
	.sda_oen(sda_padoen_o)
	);

assign led = dpwdata[11:8];

debug_port jr0(
    .rdata(dprdata),
    .rvalid(dprvalid),
    .wdata(dpwdata),
    .we(1),
    .clk(clk)
    );

endmodule

