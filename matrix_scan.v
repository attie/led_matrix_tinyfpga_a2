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

	reg  [5:0] brightness_mask_active; /* the active mask value (LEDs enabled)... from before the state advanced */
	wire [7:0] brightness_timeout;     /* used to time the output enable period */

	assign clk_pixel_load = clk_in && clk_pixel_load_en;
	assign clk_pixel = clk_in && clk_pixel_en;
	assign row_latch = clk_in && row_latch_en;

	/* produces the state-advance clock
	   states produce brighter and brighter pixels before advancing to the next row */
	clock_divider #(
		.CLK_DIV_COUNT(33) /* 33 * 2 = 66... each row takes 64 pixels, +1 latch = 65 clock cycles */
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
	timeout timeout_row_latch_delay (
		.reset(reset),
		.clk_in(clk_in),
		.start(clk_pixel_load_en),
		.value(8'd63),
		.counter(),
		.running(row_latch_delay)
	);

	/* produces the row latch enable signal
	   starts once row_latch_delay is complete
	   start is sampled on the rising clk_in edge, thus we get a latch pulse one clock cycle after the last pixel clock */
	timeout timeout_row_latch_en (
		.reset(reset),
		.clk_in(clk_in),
		.start(~row_latch_delay),
		.value(8'd1),
		.counter(),
		.running(row_latch_en)
	);

	/* decide how long to enable the LEDs for... we probably need some gamma correction here */
	assign brightness_timeout = 
		(brightness_mask_active == 6'b000001) ? 8'd1 :
		(brightness_mask_active == 6'b000010) ? 8'd2 :
		(brightness_mask_active == 6'b000100) ? 8'd4 :
		(brightness_mask_active == 6'b001000) ? 8'd8 :
		(brightness_mask_active == 6'b010000) ? 8'd16 :
		(brightness_mask_active == 6'b100000) ? 8'd32 :
		8'd0;

	/* produces the variable-width output enable signal
	   this signal is controlled by the rolling brightness_mask_active signal (brightness_mask has advanced already)
	   the wider the output_enable pulse, the brighter the LEDs */
	timeout timeout_output_enable (
		.reset(reset),
		.clk_in(clk_in),
		.start(~row_latch_en),
		.value(brightness_timeout),
		.counter(),
		.running(output_enable)
	);

	/* on completion of the row_latch_delay, we advanced the brightness mask to generate the next row of pixels */
	always @(posedge row_latch_en) begin
		brightness_mask_active <= brightness_mask;
		row_address_active <= row_address;

		if ((brightness_mask == 6'd0) || (brightness_mask == 6'b100000)) begin
			/* catch the initial value / oopsy */
			brightness_mask <= 6'b1;
			row_address <= row_address + 4'd1;
		end
		else begin
			brightness_mask <= brightness_mask << 1;
		end
	end
endmodule
