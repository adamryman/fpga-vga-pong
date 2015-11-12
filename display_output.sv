// VGA Hardware Driver
// Does timing for a VGA monitor at 25Mhz for 640x480 resolution
//
// Outputs current x and y values that are being drawn so that other
// logic can determine what color should happen at that time

module display_output (clk, reset, VGA_HS, VGA_VS, x, y, draw, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);

	output VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

    //VGA digital to analog coverter here http://www.eecg.toronto.edu/~tm4/ADV7123_a.pdf
	assign VGA_BLANK_N = 1'b1;
	assign VGA_SYNC_N = 1'b0;
	assign VGA_CLK = clk;

	input clk, reset;
	output reg VGA_HS, VGA_VS;

	output reg draw;

	output [9:0] x, y;

	wire [9:0] HS_counter, VS_counter;

	assign x = HS_counter;
	assign y = VS_counter;

	reg HS_increment, VS_increment;
	reg HS_reset;
	reg VS_reset;
	reg [2:0] ps_h, ns_h;
	reg [2:0] ps_v, ns_v;

	counter HS (.clk, .reset(HS_reset | reset), .add(HS_increment), .out(HS_counter));
	counter VS (.clk, .reset(VS_reset | reset), .add(VS_increment), .out(VS_counter));

	//Vertical Sync Timings for 25Mhz, could be changed slightly and still work R_cycle is important
	parameter [9:0] R_cycle = 480, S_cycle = R_cycle + 10, P_cycle = S_cycle + 2, Q_cycle = P_cycle + 33;

	//Horizontal Sync Timings for 25Mhz, could be changed slightly and still work R_cycle is important
	parameter [9:0] D_cycle = 640, E_cycle = D_cycle + 15, B_cycle = E_cycle + 95, C_cycle = B_cycle + 48;

	parameter [3:0] P = 0, Q = 1, R = 2, S = 3;
	parameter [3:0] B = 0, C = 1, D = 2, E = 3;

	//Two state machines, when VS is in the R state and HS is in the D state "draw" is true
	//We output the HS and VS state as when HS < 640 and VS <480 HS and VS represent the current pixel to be drawn.
	//Logic outside this module decide what color that pixel should be
	always @(*) begin
		HS_increment = 1'b1;

		if(HS_counter == C_cycle) begin
			VS_increment = 1'b1;
			HS_reset = 1'b1;
			if(VS_counter == Q_cycle - 1) begin
				VS_reset = 1'b1;
			end
			else begin
				VS_reset = 1'b0;
			end
		end
		else begin
			VS_increment = 1'b0;
			HS_reset = 1'b0;
			VS_reset = 1'b0;
		end


		case(ps_v)
			P: begin
				VGA_VS = 1'b0;
				if(VS_counter == P_cycle - 1)
					ns_v = Q;
				else
					ns_v = P;
			end
			Q: begin
				VGA_VS = 1'b1;
				if(VS_counter == Q_cycle - 1)
					ns_v = R;
				else
					ns_v = Q;
			end
			R: begin
				VGA_VS = 1'b1;
				if(VS_counter == R_cycle - 1)
					ns_v = S;
				else
					ns_v = R;
			end
			S: begin
				VGA_VS = 1'b1;
				if(VS_counter == S_cycle - 1)
					ns_v = P;
				else
					ns_v = S;
			end
		endcase

		case(ps_h)
			B: begin
				VGA_HS = 1'b0;
				draw = 1'b0;
				if(HS_counter == B_cycle - 1)
					ns_h = C;
				else
					ns_h = B;
			end
			C: begin
				VGA_HS = 1'b1;
				draw = 1'b0;
				if(HS_counter == C_cycle - 1)
					ns_h = D;
				else
					ns_h = C;
			end
			D: begin
				if(ps_v == R) begin
					draw = 1'b1;
				end
				else begin
					draw = 1'b0;
				end
				VGA_HS = 1'b1;
				if(HS_counter == D_cycle - 1)
					ns_h = E;
				else
					ns_h = D;
			end
			E: begin
				draw = 1'b0;
				VGA_HS = 1'b1;
				if(HS_counter == E_cycle - 1)
					ns_h = B;
				else
					ns_h = E;
			end

		endcase
	end

	always @(posedge clk) begin
		if (reset) begin
			ps_h <= D;
			ps_v <= R;
		end
		else begin

			ps_h <= ns_h;
			if(HS_counter == C_cycle - 1)
				ps_v <= ns_v;
		end
	end

endmodule

module display_output_testbench();
	reg clk, reset;
	reg [7:0] VGA_R, VGA_G, VGA_B;
	wire  VGA_HS ,VGA_VS;

	display_output duct (.clk,. reset, .VGA_HS, .VGA_VS);

	parameter CLOCK_PERIOD=40;
	initial clk=1;
	always begin
		#(CLOCK_PERIOD/2);
		clk = ~clk;
	end

	initial begin
		reset <= 0;
		@(posedge clk);
		reset <= 1;
		@(posedge clk);
		reset <= 0;
		#(CLOCK_PERIOD*1000000);
		$stop;
	end
endmodule
