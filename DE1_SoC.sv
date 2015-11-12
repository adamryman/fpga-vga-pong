// op-level module that defines the I/Os for the DE-1 SoC board
// Outputs to VGA monitor
// Outputs score to 7-Seg displays (HEX)
// Uses buttons for left and right paddle movements
// Uses switches for settings (Color mode, AI, Speed, Reset)

module DE1_SoC (CLOCK_50, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, KEY, LEDR, SW, VGA_HS, VGA_VS, VGA_R, VGA_B, VGA_G, VGA_CLK, VGA_BLANK_N, VGA_SYNC_N);

	input CLOCK_50;

	wire [31:0] clk;
	parameter whichClock = 15;
	clock_divider cdiv (CLOCK_50, clk);

	//VGA outputs
	output VGA_HS, VGA_VS, VGA_CLK, VGA_BLANK_N,VGA_SYNC_N;
	output [7:0] VGA_R, VGA_B, VGA_G;

	output [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
	output reg [9:0] LEDR;
	input [3:0] KEY;
	input [9:0] SW;

	assign HEX2 = 7'b1111111;
	assign HEX3 = 7'b1111111;
	assign LEDR[0] = SW[0];

	pong dosome (.clk(clk[0]), .reset(SW[9]), .VGA_HS, .VGA_VS, .VGA_R, .VGA_G(VGA_G), .VGA_B(VGA_B), .KEY, .SW(SW[8:0]), .HEX5, .HEX4, .HEX1, .HEX0, .VGA_BLANK_N, .VGA_SYNC_N, .VGA_CLK);
endmodule

// divided_clocks[0] = 25MHz, [1] = 12.5Mhz, ... [23] = 3Hz, [24] = 1.5Hz, [25] = 0.75Hz, ...
module clock_divider (clock, divided_clocks);
	input clock;
	output [31:0] divided_clocks;
	reg [31:0] divided_clocks;

	initial
		divided_clocks = 0;

	always @(posedge clock)
		divided_clocks = divided_clocks + 1;
endmodule
