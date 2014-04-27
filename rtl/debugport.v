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

/* Exposes a 33bit register on JTAG USER4
 * - on JTAG CAPTURE, bits 31:0 loaded with the
 *   last value written via wdata. bit 32 is 0.
 * - on JTAG UPDATE, if bit 32 is nonzern, bits
 *   31:0 are latched and rvalid is strobed on the
 *   next +clk
 * - on +clk, if we is 1, wdata is stored for observation
 *   via JTAG
 */
module debug_port(
	output [31:0]rdata,
	output rvalid,
	input [31:0]wdata,
	input we,
	input clk
	);

wire capture, sel, shift;
wire tck, tdi, update;

reg [32:0] data;
(* KEEP = "TRUE" *) reg [31:0] din = 0;
(* KEEP = "TRUE" *) reg [31:0] dout = 0;

assign rdata = dout;

BSCANE2 #(
	.JTAG_CHAIN(4)
	) bscan (
	.CAPTURE(capture),
	.DRCK(),
	.RESET(),
	.RUNTEST(),
	.SEL(sel),
	.SHIFT(shift),
	.TCK(tck),
	.TDI(tdi),
	.TMS(),
	.UPDATE(update),
	.TDO(data[0])
	);

always @(posedge clk)
	if (we)
		din <= wdata;

wire do_capture = sel & capture;
wire do_update = sel & update & data[32];
wire do_shift = sel & shift;

always @(posedge tck)
	if (do_capture)
		data <= { 1'b0, din };
	else if (do_update)
		dout <= data[31:0];
	else if (do_shift)
		data <= { tdi, data[32:1] };

sync s0(
	.clk_in(tck),
	.in(do_update),
	.clk_out(clk),
	.out(rvalid)
	);

endmodule


module sync(
	input clk_in,
	input clk_out,
	input in,
	output out
	);
reg toggle;
reg [2:0] sync;
always @(posedge clk_in)
	if (in) toggle <= ~toggle;
always @(posedge clk_out)
	sync <= { sync[1:0], toggle };
assign out = (sync[2] ^ sync[1]);
endmodule
