module matrix_scan (
	input reset,
	input clk_in,

	output [5:0] column_address,         /* the current column (clocking out now) */
	output reg [3:0] row_address,        /* the current row (clocking out now) */
	output reg [3:0] row_address_active, /* the active row (LEDs enabled) */

	output clk_pixel_load,
	output clk_pixel,
	output row_latch,
	output output_enable, /* the minimum output enable pulse should not be shorter than 1us... */

	output reg [5:0] brightness_mask /* used to pick a bit from the sub-pixel's brightness */
);
	localparam state_timeout_overlap = 'd67;

	reg [1:0] state = 2'b00;
	wire clk_state;
	wire state_advance;

	wire clk_pixel_load_en;/* enables the pixel load clock */
	reg  clk_pixel_en;    /* enables the pixel clock, delayed by one cycle from the load clock */
	reg  [1:0] row_latch_state = 2'b00;

	wire clk_row_address; /* on the falling edge, feed the row address to the active signals */

	reg  [5:0] brightness_mask_active; /* the active mask value (LEDs enabled)... from before the state advanced */
	wire [9:0] brightness_timeout;     /* used to time the output enable period */
	wire [9:0] brightness_counter;     /* used to control the state advance overlap */

	assign clk_pixel_load = clk_in && clk_pixel_load_en;
	assign clk_pixel = clk_in && clk_pixel_en;
	assign row_latch = row_latch_state[1:0] == 2'b10;

	assign clk_state = state == 2'b10;

	/* produce 64 load clocks per line...
	   external logic should present the pixel value on the rising edge */
	timeout #(
		.COUNTER_WIDTH(7)
	) timeout_clk_pixel_load_en (
		.reset(reset),
		.clk_in(clk_in),
		.start(clk_state),
		.value(7'd64),
		.counter(),
		.running(clk_pixel_load_en)
	);

	/* produce the column address
	   counts from 63 -> 0 and then stops
	   advances out-of-phase with the pixel clock */ 
	timeout #(
		.COUNTER_WIDTH(6)
	) timeout_column_address (
		.reset(reset),
		.clk_in(clk_in),
		.start(clk_state),
		.value(6'd63),
		.counter(column_address),
		.running()
	);

	/* produces the pixel clock enable signal and row_latch_state
	   there are 64 pixels per row, this starts immediately after a state advance */
	always @(negedge clk_in) begin
		clk_pixel_en <= clk_pixel_load_en;
		row_latch_state <= { row_latch_state[0], clk_pixel_load_en };
	end

	/* decide how long to enable the LEDs for... we probably need some gamma correction here */
	assign brightness_timeout = 
		(brightness_mask_active == 6'b000001) ? 10'd23 :
		(brightness_mask_active == 6'b000010) ? 10'd46 :
		(brightness_mask_active == 6'b000100) ? 10'd92 :
		(brightness_mask_active == 6'b001000) ? 10'd184 :
		(brightness_mask_active == 6'b010000) ? 10'd368 :
		(brightness_mask_active == 6'b100000) ? 10'd736 :
		10'd1;

	/* produces the variable-width output enable signal
	   this signal is controlled by the rolling brightness_mask_active signal (brightness_mask has advanced already)
	   the wider the output_enable pulse, the brighter the LEDs */
	timeout #(
		.COUNTER_WIDTH(10)
	) timeout_output_enable (
		.reset(reset),
		.clk_in(clk_in),
		.start(~row_latch),
		.value(brightness_timeout),
		.counter(brightness_counter),
		.running(output_enable)
	);

	/* we want to overlap the pixel clock out with the previous output
	   enable... but we do not want to start too early... */
	assign state_advance = !output_enable || (state_timeout_overlap < brightness_counter);

	/* shift the state advance signal into the bitfield */
	always @(posedge clk_in, posedge reset) begin
		if (reset) begin
			state <= 2'b1;
		end
		else begin
			state <= { state[0], state_advance };
		end
	end

	/* on completion of the row_latch, we advanced the brightness mask to generate the next row of pixels */
	always @(posedge row_latch, posedge reset) begin
		if (reset) begin
			brightness_mask <= 6'd0;
			brightness_mask_active <= 6'd0;
			row_address <= 4'd0;
			row_address_active <= 4'd0;
		end
		else begin
			brightness_mask_active <= brightness_mask;
			row_address_active <= row_address;

			if ((brightness_mask == 6'd0) || (brightness_mask == 6'b000001)) begin
				/* catch the initial value / oopsy */
				brightness_mask <= 6'b100000;
				row_address <= row_address + 4'd1;
			end
			else begin
				brightness_mask <= brightness_mask >> 1;
			end
		end
	end
endmodule
