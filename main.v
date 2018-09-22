module main (
	inout pin1,
	inout pin2,
	inout pin3,
	inout pin4,
	inout pin5,
	inout pin6,
	inout pin7,
	inout pin8,
	inout pin9,
	inout pin10,
	inout pin11,
	// 12, 13, 14, 15 ==> JTAG
	inout pin16,
	inout pin17,
	inout pin18,
	inout pin19,
	inout pin20,
	inout pin21,
	inout pin22
);
	wire debug;

	wire global_reset;

	wire clk_root;
	wire clk_pixel;

	wire row_latch;

	wire [7:0] column_address;
	wire [3:0] row_address;
	wire [5:0] brightness_mask;

	wire [5:0] rgb_red;
	wire [5:0] rgb_green;
	wire [5:0] rgb_blue;

	wire [2:0] rgb1; /* the current RGB value for the top-half of the display */
	wire [2:0] rgb2; /* the current RGB value for the bottom-half of the display */

	OSCH #(
		.NOM_FREQ("7.00")
	) osc (
		.STDBY(1'b0), 
		.OSC(clk_root),
		.SEDSTDBY()
	);

	/* produces a global reset */
	timeout timeout_global_reset (
		.reset(1'b0),
		.clk_in(clk_root),
		.start(1'b1),
		.value(8'd16),
		.counter(),
		.running(global_reset)
	);

	/* produce signals to scan a 64x32 LED matrix, with 6-bit color */
	matrix_scan matscan1 (
		.reset(global_reset),
		.clk_in(clk_root),
		.column_address(column_address),
		.row_address(row_address),
		.clk_pixel(clk_pixel),
		.row_latch(row_latch),
		.output_enable(output_enable),
		.brightness_mask(brightness_mask)
	);

	/* produce signals to fill a LED matrix with a color gradient / rainbow */
	rainbow_generator bowgen (
		.column_address(column_address),
		.red(rgb_red),
		.green(rgb_green),
		.blue(rgb_blue)
	);

	/* apply the brightness mask to the calculated sub-pixel value */
	assign rgb1[0] = ((rgb_red   & brightness_mask) != 0);
	assign rgb1[1] = ((rgb_green & brightness_mask) != 0);
	assign rgb1[2] = ((rgb_blue  & brightness_mask) != 0);
	assign rgb2 = rgb1; /* mirror top/bottom */

	/* use this signal for insight! */
	assign debug = 1'b0;

	/* assign signals to pins */
	/* Debug LED  */ assign pin1 = debug;
	/* #OE        */ assign pin2 = ~output_enable;
	/* A / Row[0] */ assign pin3 = row_address[0];
	/* B / Row[1] */ assign pin4 = row_address[1];
	/* C / Row[2] */ assign pin5 = row_address[2];
	/* D / Row[3] */ assign pin6 = row_address[3];
	/*            */ assign pin7 = 1'bz;
	/*            */ assign pin8 = 1'bz;
	/*            */ assign pin9 = 1'bz;
	/* Pixel Clk  */ assign pin10 = clk_pixel;
	/* Row Latch  */ assign pin11 = row_latch;
	// 12, 13, 14, 15 ==> JTAG
	/* Red   1    */ assign pin16 = rgb1[0];
	/* Green 1    */ assign pin17 = rgb1[1];
	/* Blue  1    */ assign pin18 = rgb1[2];
	/* Red   2    */ assign pin19 = rgb2[0];
	/* Green 2    */ assign pin20 = rgb2[1];
	/* Blue  2    */ assign pin21 = rgb2[2];
	/*            */ assign pin22 = 1'bz;
endmodule
