module matrix_scan (
	input reset,
	input clk_in,

	output [5:0] column_address,         /* the current column (clocking out now) */
	output reg [3:0] row_address,        /* the current row (clocking out now) */
	output reg [3:0] row_address_active, /* the active row (LEDs enabled) */

	output clk_pixel_load,
	output clk_pixel,
	output row_latch,
	output output_enable,

	output reg [5:0] brightness_mask /* used to pick a bit from the sub-pixel's brightness */
);
	wire clk_state;

	wire clk_pixel_load_en;/* enables the pixel load clock */
	reg  clk_pixel_en;    /* enables the pixel clock, delayed by one cycle from the load clock */
	wire row_latch_delay; /* delays the row_latch timeout */
	wire row_latch_en;    /* enables the row latch */

	wire clk_row_address; /* on the falling edge, feed the row address to the active signals */

	reg  [5:0] brightness_mask_active; /* the active mask value (LEDs enabled)... from before the state advanced */
	wire [7:0] brightness_timeout;     /* used to time the output enable period */

	assign clk_pixel_load = clk_in && clk_pixel_load_en;
	assign clk_pixel = clk_in && clk_pixel_en;
	assign row_latch = clk_in && row_latch_en;

	/* produces the state-advance clock
	   states produce brighter and brighter pixels before advancing to the next row
	   if this value is too small, you'll see the rows start to bleed upwards
	   too large and the display will get dimmer and ultimately start flickering
	   this timeout must encompass the following:
	          1 cycle     - for clk_pixel_load_en -> clk_pixel_en delay
	      +  64 cycles    - 1 row of pixel clocks
	      +   1 cycle     - row latch
		  =  66 cycles  A - total duration for one row clock-out

	      +   1 cycle     - output enable delay
	      +  64 cycles    - max brightness duration of output enable
	      +  14 cycles    - row_address update delay (to reduce bleed)... x2 to center it
	      = 145 cycles  B - total duration from start of state to start of next state's otuput enable

	      -  66 cycles    - (A)
	      =  79 cycles  C - minimum state clock rate

	      /   2           - clock divider modules divide twice (toggle on zero)
	      =  40 cycles  D - mimimum value of clock divider */
	clock_divider #(
		.CLK_DIV_WIDTH(8),
		.CLK_DIV_COUNT(40) /* see calculations above, use (D) here... */
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

	/* produces the pixel clock enable signal
	   there are 64 pixels per row, this starts immediately after a state advance */
	always @(posedge clk_in) begin
		clk_pixel_en <= clk_pixel_load_en;
	end

	/* delays the row latch enable
	   after 63x pixel clocks, we let the latch enable timeout run */
	timeout #(
		.COUNTER_WIDTH(6)
	) timeout_row_latch_delay (
		.reset(reset),
		.clk_in(clk_in),
		.start(clk_pixel_load_en),
		.value(6'd63),
		.counter(),
		.running(row_latch_delay)
	);

	/* produces the row latch enable signal
	   starts once row_latch_delay is complete
	   start is sampled on the rising clk_in edge, thus we get a latch pulse one clock cycle after the last pixel clock */
	timeout #(
		.COUNTER_WIDTH(1)
	) timeout_row_latch_en (
		.reset(reset),
		.clk_in(clk_in),
		.start(~row_latch_delay),
		.value(1'd1),
		.counter(),
		.running(row_latch_en)
	);

	/* decide how long to enable the LEDs for... we probably need some gamma correction here */
	assign brightness_timeout = 
		(brightness_mask_active == 6'b000001) ? 8'd1 :
		(brightness_mask_active == 6'b000010) ? 8'd2 :
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
		.start(~row_latch_en),
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
		.COUNTER_WIDTH(3)
	) timeout_row_address (
		.reset(reset),
		.clk_in(clk_in),
		.start(~output_enable),
		.value('d7),
		.counter(),
		.running(clk_row_address)
	);

	/* on completion of the row_latch_delay, we advanced the brightness mask to generate the next row of pixels */
	always @(posedge row_latch_en) begin
		brightness_mask_active <= brightness_mask;

		if ((brightness_mask == 6'd0) || (brightness_mask == 6'b100000)) begin
			/* catch the initial value / oopsy */
			brightness_mask <= 6'b1;
			row_address <= row_address + 4'd1;
		end
		else begin
			brightness_mask <= brightness_mask << 1;
		end
	end

	/* push the row address to the active output */
	always @(negedge clk_row_address) begin
		row_address_active <= row_address;
	end
endmodule
