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
	wire clk_state;

	wire clk_pixel_load_en;/* enables the pixel load clock */
	reg  clk_pixel_en;    /* enables the pixel clock, delayed by one cycle from the load clock */
	reg  [1:0] row_latch_state = 2'b0;

	wire clk_row_address; /* on the falling edge, feed the row address to the active signals */

	reg  [5:0] brightness_mask_active; /* the active mask value (LEDs enabled)... from before the state advanced */
	wire [7:0] brightness_timeout;     /* used to time the output enable period */

	assign clk_pixel_load = clk_in && clk_pixel_load_en;
	assign clk_pixel = clk_in && clk_pixel_en;
	assign row_latch = row_latch_state == 2'b10;

	/* produces the state-advance clock
	   states produce brighter and brighter pixels before advancing to the next row
	   if this value is too small, you'll see the rows start to bleed upwards
	   too large and the display will get dimmer and ultimately start flickering
	   this timeout must encompass the following:
	          1 cycle     - for clk_pixel_load_en -> clk_pixel_en delay
	      +  64 cycles    - 1 row of pixel clocks
	      +   1 cycle     - row latch
		  =  66 cycles  A - total duration for one row clock-out

	      /   2           - clock divider modules divide twice (toggle on zero)
	      =  33 cycles  B - mimimum value of clock divider

	   the brightness bits are now shifted out MSB to LSB, allowing a much larger
	   'off' period in which to update the row address... */
	clock_divider #(
		.CLK_DIV_WIDTH(8),
		.CLK_DIV_COUNT(33) /* see calculations above, use (B) here... */
	) clkdiv_state (
		.reset(reset),
		.clk_in(clk_in),
		.clk_out(clk_state)
	);

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
		(brightness_mask_active == 6'b000001) ? 8'd2 :
		(brightness_mask_active == 6'b000010) ? 8'd4 :
		(brightness_mask_active == 6'b000100) ? 8'd8 :
		(brightness_mask_active == 6'b001000) ? 8'd16 :
		(brightness_mask_active == 6'b010000) ? 8'd32 :
		(brightness_mask_active == 6'b100000) ? 8'd64 :
		8'd0;

	/* produces the variable-width output enable signal
	   this signal is controlled by the rolling brightness_mask_active signal (brightness_mask has advanced already)
	   the wider the output_enable pulse, the brighter the LEDs */
	timeout #(
		.COUNTER_WIDTH(8)
	) timeout_output_enable (
		.reset(reset),
		.clk_in(clk_in),
		.start(~row_latch),
		.value(brightness_timeout),
		.counter(),
		.running(output_enable)
	);

	/* produces the delayed row latch signal
	   this signal needs to be approximately at the midpoint between output disable and enable edges
	   if it's too close to one or another, then we get more bleed
	   too small a value causes bleed down, too large causes bleed up
	   aim for the middle, but you might have to make the gap larger */
	timeout #(
		.COUNTER_WIDTH(5)
	) timeout_row_address (
		.reset(reset),
		.clk_in(clk_in),
		.start(~output_enable),
		.value('d31),
		.counter(),
		.running(clk_row_address)
	);

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
