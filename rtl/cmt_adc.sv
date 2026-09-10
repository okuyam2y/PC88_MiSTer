//============================================================================
//  PC8801SR - cassette (CMT) input
//
//  Copyright (C) 2026 Yoshiaki Okuyama
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

//
// cmt_adc - LTC2308 samples of the cassette input to a two-level signal
//
// The comparator follows the centre of the input with a first-order low pass rather than
// slicing at mid scale, since the offset and the level of a recorder's output are not known
// in advance. A new level has to survive MINW samples before it is passed on.
//
module cmt_adc #(
	parameter AVG_SHIFT = 12,   // centre estimate time constant, in samples: 21 ms at 192 kHz
	parameter MINW      = 8     // samples a new level must survive: 42 us at 192 kHz
)(
	input             clk,
	input             reset,

	input             sample,     // 1 for one clock when a new ADC sample is on `data`
	input      [11:0] data,

	output reg        level
);

localparam HW = (MINW <= 2) ? 1 : $clog2(MINW);

// The accumulator holds the centre scaled by 2^AVG_SHIFT; the estimate is its top 12 bits.
reg [11+AVG_SHIFT:0] centre_acc;
wire          [11:0] centre = centre_acc[11+AVG_SHIFT -: 12];

reg          sliced;
reg [HW-1:0] held;

always @(posedge clk) begin
	if (reset) begin
		centre_acc <= {1'b1, {(11+AVG_SHIFT){1'b0}}};   // mid scale
		sliced     <= 1'b0;
		level      <= 1'b0;
		held       <= 0;
	end
	else if (sample) begin
		centre_acc <= centre_acc - {{AVG_SHIFT{1'b0}}, centre} + {{AVG_SHIFT{1'b0}}, data};

		if (data < centre) sliced <= 1'b0;
		if (data > centre) sliced <= 1'b1;

		if (sliced != level) begin
			if (held == HW'(MINW - 1)) begin
				level <= sliced;
				held  <= 0;
			end
			else held <= held + 1'd1;
		end
		else held <= 0;      // the new level did not survive
	end
end

endmodule
