// Full logic for pong, moving paddles, collision detection, and ball movement

`define PADDLE_WIDTH 15
`define PADDLE_HEIGHT 50

`define PADDLE_L_X 50

`define PADDLE_R_X 590

`define BALL_WIDTH 15

`define SCREEN_HEIGHT 479
`define SCREEN_WIDTH 639

`define SPEED 16
`define BALL_SPEED 16

//
module pong (clk, reset, VGA_HS, VGA_VS, VGA_R, VGA_G, VGA_B, KEY, SW, HEX5, HEX4, HEX1, HEX0, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
	input clk, reset;
	output VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;
	input [3:0] KEY;
	input [8:0] SW;
	output [6:0] HEX0, HEX1, HEX4, HEX5;
	output VGA_HS, VGA_VS;
	output reg [7:0] VGA_R, VGA_G, VGA_B;
	wire [9:0] current_x, current_y;
	wire draw;
	reg drawing;

	// Display Driver
	display_output drawer (.clk, .reset, .VGA_HS, .VGA_VS, .x(current_x), .y(current_y), .draw, .VGA_BLANK_N, .VGA_SYNC_N, .VGA_CLK);

	reg paddle_r_draw;
	reg paddle_l_draw;
	reg ball_draw;
	reg [9:0] paddle_l_y, paddle_r_y;

	reg screen_reset;

	wire [9:0] ball_x, ball_y;
	reg speed_x, speed_y;

	reg right_win, left_win;

	reg ps_draw, ns_draw;

	reg [1:0] ps_ai_r, ns_ai_r;
	reg [1:0] ps_ai_l, ns_ai_l;

	reg [2:0] ps_ball_collision, ns_ball_collision;
	reg [1:0] ps_ball_collision_y, ns_ball_collision_y;

	reg [1:0] ps_woah, ns_dude;
	score myscore (.clk, .reset, .right_win, .left_win, .HEX5, .HEX4, .HEX1, .HEX0);

	initial begin
		speed_x = 1'b1;
		speed_y = 1'b1;
	end

	wire r_up, r_down, l_up, l_down;
	reg ai_r_up, ai_r_down, ai_l_up, ai_l_down;

	reg [18:0] clk_div;

	user_input r_up_in   (.clk, .reset, .in(~KEY[0] | ai_r_up), .out(r_up));
	user_input r_down_in (.clk, .reset, .in(~KEY[1] | ai_r_down), .out(r_down));
	user_input l_up_in   (.clk, .reset, .in(~KEY[2] | ai_l_up), .out(l_up));
	user_input l_down_in (.clk, .reset, .in(~KEY[3] | ai_l_down), .out(l_down));

	updown paddle_r_y_updown (.clk, .reset(reset | screen_reset), .set(`SCREEN_HEIGHT / 2) , .limit(`SCREEN_HEIGHT - `PADDLE_HEIGHT), .add(r_down), .subtract(r_up), .out(paddle_r_y), .rap());
	updown paddle_l_y_updown (.clk, .reset(reset | screen_reset), .set(`SCREEN_HEIGHT / 2), .limit(`SCREEN_HEIGHT - `PADDLE_HEIGHT), .add(l_down), .subtract(l_up), .out(paddle_l_y), .rap());

	counter #(.WIDTH(19)) div (.clk, .reset, .add(1'b1), .out(clk_div));

	ball theball (.clk, .reset(reset | screen_reset), .x(ball_x), .y(ball_y), .speed_x, .speed_y);

	parameter [2:0] right_win_state = 1, left_win_state = 2, right_paddle = 3, left_paddle = 4, left = 5, right = 6;

	// Main game loop
	// 1. Drawing
	// 2. Ai
	// 3. Collision
	always @(*) begin
		case(ps_draw)
			0: begin
				should_draw;

				draw_square(`PADDLE_R_X, paddle_r_y, `PADDLE_WIDTH, `PADDLE_HEIGHT, paddle_r_draw);
				draw_square(`PADDLE_L_X, paddle_l_y, `PADDLE_WIDTH, `PADDLE_HEIGHT, paddle_l_draw);
				draw_square(ball_x, ball_y, `BALL_WIDTH, `BALL_WIDTH, ball_draw);

				if(paddle_r_draw) begin
					VGA_B = 8'b11111111;
					VGA_R = 8'b00000000;
					VGA_G = 8'b00000000;
					end
				else if (paddle_l_draw) begin
					VGA_R = 8'b11111111;
					VGA_B = 8'b00000000;
					VGA_G = 8'b00000000;
				end
				else if (ball_draw) begin
					VGA_G = 8'b11111111;
					VGA_R = 8'b00000000;
					VGA_B = 8'b00000000;
				end
				else begin
					if(SW[3]) begin
						case(ps_woah)
							0: begin
								VGA_R = 8'b00000000;
								VGA_G = 8'b11111111;
								VGA_B = 8'b11111111;
								ns_dude = 1;
							end
							1: begin
								VGA_G = 8'b00000000;
								VGA_R = 8'b11111111;
								VGA_B = 8'b11111111;
								ns_dude = 2;
							end
							2: begin
								VGA_B = 8'b00000000;
								VGA_G = 8'b11111111;
								VGA_R = 8'b11111111;
								ns_dude = 0;
							end
							default: begin
								VGA_R = 8'b11111111;
								VGA_G = 8'b11111111;
								VGA_B = 8'b11111111;
								ns_dude = 0;
							end
						endcase
					end
					else if (SW[2]) begin
						VGA_R = 8'b11111111;
						VGA_G = 8'b11111111;
						VGA_B = 8'b11111111;
					end
					else begin
						VGA_R = 8'b00000000;
						VGA_G = 8'b00000000;
						VGA_B = 8'b00000000;
					end
				end

			end
			1: begin
				should_draw;

				VGA_R = 8'b00000000;
				VGA_G = 8'b00000000;
				VGA_B = 8'b00000000;
				paddle_r_draw = 1'b0;
				paddle_l_draw = 1'b0;
				ball_draw = 1'b0;
			end
		endcase

		case(ps_ai_r)
			0: begin
				right_ai_next;
				ai_r_up = 0;
				ai_r_down = 0;
			end
			1: begin
				right_ai_next;
				ai_r_up = 0;
				ai_r_down = 1;
			end
			2: begin
				right_ai_next;
				ai_r_up = 1;
				ai_r_down = 0;
			end
			default:
				ns_ai_r = 0;
		endcase

		case(ps_ai_l)
			0: begin
				left_ai_next;
				ai_l_up = 0;
				ai_l_down = 0;
			end
			1: begin
				left_ai_next;
				ai_l_up = 0;
				ai_l_down = 1;
			end
			2: begin
				left_ai_next;
				ai_l_up = 1;
				ai_l_down = 0;
			end
			default:
				ns_ai_l = 0;
		endcase

		case(ps_ball_collision)
			right: begin
				ball_collision_next;
				screen_reset = 1'b0;
				left_win = 0;
				right_win = 0;
				speed_x = 1'b1;
			end
			left: begin
				ball_collision_next;
				screen_reset = 1'b0;
				left_win = 0;
				right_win = 0;
				speed_x = 1'b0;
			end
			left_win_state: begin
				ns_ball_collision = left;
				screen_reset = 1'b1;
				left_win = 1;
				right_win = 0;
				speed_x = 1'b1;
			end
			right_win_state: begin
				ns_ball_collision = right;
				screen_reset = 1'b1;
				right_win = 1;
				left_win = 0;
				speed_x = 1'b0;
			end
			right_paddle: begin
				ns_ball_collision = left;
				speed_x = 1'b0;
				screen_reset = 1'b0;
				left_win = 0;
				right_win = 0;
			end
			left_paddle: begin
				ns_ball_collision = right;
				speed_x = 1'b1;
				screen_reset = 1'b0;
				left_win = 0;
				right_win = 0;
			end
			default: begin
				ns_ball_collision = 0;
				screen_reset = 1'bx;
				left_win = 1'bx;
				right_win = 1'bx;
				speed_x = 1'bx;
			end
		endcase

		case(ps_ball_collision_y)
			0: begin
				ball_collision_next_y;
				speed_y = 1'b0;
			end
			3: begin
				ball_collision_next_y;
				speed_y = 1'b1;
			end
			1: begin
				ns_ball_collision_y = 3;
				speed_y = 1'b1;
			end
			2: begin
				ns_ball_collision_y = 0;
				speed_y = 1'b0;
			end
			default: ns_ball_collision_y = 0;
		endcase

	end

	always @(posedge clk) begin
		if(reset) begin
			ps_draw <= 1'b1;
			ps_ai_l <= 0;
			ps_ai_r <= 0;
			ps_ball_collision <= right;
			ps_ball_collision_y <= 0;
			ps_woah <= 0;
		end
		else begin
			ps_draw <= ns_draw;
			ps_ai_l <= ns_ai_l;
			ps_ai_r <= ns_ai_r;
			ps_ball_collision <= ns_ball_collision;
			ps_ball_collision_y <= ns_ball_collision_y;
			if(clk_div == 0) begin
				ps_woah <= ns_dude;
			end
			else begin
				ps_woah <= ps_woah;
			end
		end
	end


	//TASKS

	task draw_square;
		input [9:0] x, y, w, h;
		//input [8:0] rgb [0:3];
		output draw_this;
		if(current_x >= x && current_y >= y && current_x <= x + w && current_y <= y + h) begin
			draw_this = 1'b1;
		end
		else begin
			draw_this = 1'b0;
		end
	endtask

	task should_draw;
		if(current_x < `SCREEN_WIDTH && current_y < `SCREEN_HEIGHT && draw) begin
			ns_draw = 1'b0;
		end
		else begin
			ns_draw = 1'b1;
		end
	endtask

	task right_ai_next;
		if(ball_y > (paddle_r_y + (`PADDLE_HEIGHT / 2)- (`BALL_WIDTH / 2)) && speed_x && SW[7]) begin
			ns_ai_r = 1;
		end
		else if(speed_x && SW[7])begin
			ns_ai_r = 2;
		end
		else begin
			ns_ai_r = 0;
		end
	endtask

	task left_ai_next;
		if(ball_y > (paddle_l_y + (`PADDLE_HEIGHT / 2)- (`BALL_WIDTH / 2)) && ~speed_x && SW[8]) begin
			ns_ai_l = 1;
		end
		else if(~speed_x && SW[8])begin
			ns_ai_l = 2;
		end
		else begin
			ns_ai_l = 0;
		end
	endtask

	task ball_collision_next;
		if(ball_x == 0) begin //ball hit left side
			ns_ball_collision = right_win_state;
		end
		else if (ball_x == `SCREEN_WIDTH  - `BALL_WIDTH) begin //ball hit right side
			ns_ball_collision = left_win_state;
		end
		else if (ball_x == `PADDLE_L_X + `PADDLE_WIDTH
					&& (ball_y + `BALL_WIDTH >= paddle_l_y
					&& ball_y <= paddle_l_y + `PADDLE_HEIGHT)) begin //ball hit left paddle
			ns_ball_collision = left_paddle;
		end
		else if (ball_x + `BALL_WIDTH == `PADDLE_R_X
					&& (ball_y + `BALL_WIDTH >= paddle_r_y
					&& ball_y <= paddle_r_y + `PADDLE_HEIGHT)) begin //ball hit right paddle
			ns_ball_collision = right_paddle;
		end
		else if(speed_x) begin//ball doing something else
			ns_ball_collision = right ;
		end
		else begin
			ns_ball_collision = left;
		end
	endtask

	task ball_collision_next_y;
		if(ball_y == 0) begin
			ns_ball_collision_y = 1;
		end
		else if (ball_y == `SCREEN_HEIGHT - `BALL_WIDTH) begin
			ns_ball_collision_y = 2;
		end
		else if(speed_y == 0)
			ns_ball_collision_y = 0;
		else
			ns_ball_collision_y = 3;
	endtask
endmodule

module pong_testbench();
	reg clk, reset;
	reg [7:0] VGA_R, VGA_G, VGA_B;
	reg [3:0] KEY;
	wire  VGA_HS ,VGA_VS;
	reg r_up, r_down;

	assign KEY[0] = ~r_up;
	assign KEY[1] = ~r_down;


	pong duct (.clk,. reset, .VGA_HS, .VGA_VS, .VGA_R, .VGA_G, .VGA_B, .KEY);

	parameter CLOCK_PERIOD=40;
	initial clk=1;
	always begin
		#(CLOCK_PERIOD/2);
		clk = ~clk;
	end

	initial begin
		KEY[3] <= 0;
		KEY[2] <= 0;
		r_down <= 0;
		r_up <= 0;
		reset <= 0;
		@(posedge clk);
		reset <= 1;
		@(posedge clk);
		reset <= 0;
		#(CLOCK_PERIOD*100);
		r_up <= 1;
		#(CLOCK_PERIOD*100);
		r_up <= 0;
		@(posedge clk);
		@(posedge clk);
		r_down <= 1;
		#(CLOCK_PERIOD*100);
		r_down <= 0;
		@(posedge clk);
		@(posedge clk);



		r_up <= 1;
		#(CLOCK_PERIOD*100);
		r_up <= 0;
		@(posedge clk);
		@(posedge clk);
		r_down <= 1;
		#(CLOCK_PERIOD*100000);
		r_down <= 0;
		@(posedge clk);
		@(posedge clk);
		//#(CLOCK_PERIOD*1000000);
		$stop;
	end
endmodule

module ball (clk, reset, x, y, speed_x, speed_y);
	input clk, reset;
	input speed_x, speed_y;
	output reg [9:0] x, y;
	reg [`BALL_SPEED - 1:0] clk_div;
	reg right, left, up, down;

	updown ball_x (.clk, .reset(reset), .set(10'd320) , .limit(`SCREEN_WIDTH - `BALL_WIDTH), .add(right), .subtract(left), .out(x), .rap());
	updown ball_y (.clk, .reset(reset), .set(10'd240) , .limit(`SCREEN_HEIGHT - `BALL_WIDTH), .add(down), .subtract(up), .out(y), .rap());

	updown #(.WIDTH(`BALL_SPEED)) div (.clk, .reset, .set(), .add(1'b1), .subtract(), .out(clk_div), .rap(1'b1), .limit());

	always @(*) begin
		if(speed_x && clk_div == 0) begin
			right = 1'b1;
			left = 1'b0;
		end
		else if(~speed_x && clk_div == 0) begin
			right = 1'b0;
			left = 1'b1;
		end else begin
			right = 1'b0;
			left = 1'b0;
		end

		if(speed_y && clk_div == 0) begin
			down = 1'b1;
			up = 1'b0;
		end
		else if(~speed_y && clk_div == 0) begin
			down = 1'b0;
			up = 1'b1;
		end else begin
			down = 1'b0;
			up = 1'b0;
		end

	end

endmodule


module ball_testbench();
	reg clk, reset;
	wire [9:0] x, y;
	reg speed_x, speed_y;

	ball ball_test (clk, reset, x, y, speed_x, speed_y);

	parameter CLOCK_PERIOD=40;
	initial clk=1;
	always begin
		#(CLOCK_PERIOD/2);
		clk = ~clk;
	end

	initial begin
		speed_x = 1'b0;
		speed_y = 1'b0;
		reset <= 0;
		@(posedge clk);
		reset <= 1;
		@(posedge clk);
		reset <= 0;

		#(CLOCK_PERIOD*100);
		speed_x = 1'b1;
		#(CLOCK_PERIOD*100);
		speed_y = 1'b1;
		#(CLOCK_PERIOD*100);
		speed_x = 1'b0;
		speed_y = 1'b0;
		#(CLOCK_PERIOD*100);
		speed_y = 1'b1;
		#(CLOCK_PERIOD*10);
		$stop;
	end

endmodule

module score (clk, reset, right_win, left_win, HEX5, HEX4, HEX1, HEX0);
	input clk, reset, right_win, left_win;
	output [6:0] HEX5, HEX4, HEX1, HEX0;

	reg [8:0] right_wins, left_wins;

	reg right_score, left_score;

	reg [1:0] ps, ns;

	updown rightwin (.clk, .reset(reset), .add(right_score), .out(right_wins), .limit(8'd99), .rap());
	updown leftwin (.clk, .reset(reset), .add(left_score), .out(left_wins), .limit(8'd99), .rap());

	seven_seg rightlower (.value(right_wins % 10), .HEX(HEX0));
	seven_seg rightupper (.value(right_wins / 10), .HEX(HEX1));

	seven_seg leftlower (.value(left_wins % 10), .HEX(HEX4));
	seven_seg leftupper (.value(left_wins / 10), .HEX(HEX5));

	always @(*)
		case(ps)
			0: begin
				check_win;
				right_score = 0;
				left_score = 0;
			end
			1: begin
				check_win;
				right_score = 1;
				left_score = 0;
			end
			2: begin
				check_win;
				right_score = 0;
				left_score = 1;
			end
			default: begin
				check_win;
				right_score = 0;
				left_score = 0;
			end
		endcase

	always @(posedge clk)
		if(reset)
			ps <= 0;
		else
			ps <= ns;

	task check_win;
		if(right_win)
		   ns = 2'd1;
		else if (left_win)
			ns = 2'd2;
		else
			ns = 2'd0;
	endtask
endmodule

module seven_seg(value, HEX);
	input [3:0] value;
	output reg [6:0] HEX;

	always @(*)
		case(value)
			0: HEX = 7'b1000000;
			1: HEX = 7'b1111001;
			2: HEX = 7'b0100100;
			3: HEX = 7'b0110000;
			4: HEX = 7'b0011001;
			5: HEX = 7'b0010010;
			6: HEX = 7'b0000010;
			7: HEX = 7'b1111000;
			8: HEX = 7'b0000000;
			9: HEX = 7'b0010000;
			default: HEX = 7'b1000000;
		endcase
endmodule

module user_input(clk, reset, in, out);
	input clk, reset, in;
	output reg out;

	reg [`SPEED - 1:0] clk_div;
	updown #(.WIDTH(`SPEED)) div (.clk, .reset, .set(), .add(1'b1), .subtract(), .out(clk_div), .rap(1'b1), .limit());

	always @(*) begin
	 if(clk_div == 0 && in)
		out = 1'b1;
	else
		out = 1'b0;
	end

endmodule



module counter #(parameter WIDTH=10) (clk, reset, add, out);
	input clk, reset, add;
	output reg [WIDTH - 1:0] out;

	always @(posedge clk)
		if (reset)
			out <= 0;
		else
			out <= out + add;
endmodule

module updown #(parameter WIDTH=10) (clk, reset, set, limit, add, subtract, out, rap);
	input clk, reset, add, subtract;
	input [WIDTH - 1:0] set, limit;
	input rap;
	output reg [WIDTH - 1:0] out;

	always @(posedge clk)
		if (reset)
			out <= set;
		else if(add && ~subtract && out <= (limit - 1))
			out <= out + add;
		else if (subtract && ~add && out > 0)
			out <= out - subtract;
		else if (add && ~subtract && (out >= (limit - 100)) && rap )
			out <= 0;
endmodule

module updown_testbench();
	reg clk, reset;
	reg add, subtract;
	wire [9:0] out;

	updown duct (.clk,. reset, .set(10'd5), .limit(10'd233), .add, .subtract, .out, .rap());

	parameter CLOCK_PERIOD=40;
	initial clk=1;
	always begin
		#(CLOCK_PERIOD/2);
		clk = ~clk;
	end

	initial begin
		add <= 0;
		subtract <= 0;
		reset <= 0;
		@(posedge clk);
		reset <= 1;
		@(posedge clk);
		reset <= 0;
		@(posedge clk);
		@(posedge clk);
		add <= 1;
		@(posedge clk);
		@(posedge clk);
		add <= 0;
		@(posedge clk);
		@(posedge clk);
		subtract <= 1;
		@(posedge clk);
		@(posedge clk);
		subtract <= 0;
		@(posedge clk);
		@(posedge clk);
		add <= 1;
		subtract <= 1;
		@(posedge clk);
		@(posedge clk);
		subtract <= 0;
		add <= 1;
		#(CLOCK_PERIOD*10);
		add <= 0;
		@(posedge clk);
		subtract <= 1;
		#(CLOCK_PERIOD*15);
		subtract <= 0;
		@(posedge clk);
		@(posedge clk);
		$stop;
	end
endmodule
