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
	wire clk_matrix;
	wire clk_pixel_load;
	wire clk_pixel;

	wire row_latch;

	wire [7:0] ram_a_data_in;
	wire [7:0] ram_a_data_out;
	wire [11:0] ram_a_address;
	wire ram_a_write_enable;
	wire ram_a_clk_enable;
	wire ram_a_reset;

	wire [15:0] ram_b_data_out;
	wire [10:0] ram_b_address;
	wire ram_b_clk_enable;
	wire ram_b_reset;

	wire [15:0] pixel_rgb565_top;
	wire [15:0] pixel_rgb565_bottom;

	wire uart_rx;

	wire [5:0] column_address;
	wire [3:0] row_address;
	wire [3:0] row_address_active;
	wire [5:0] brightness_mask;

	wire [2:0] rgb_enable;
	wire [2:0] rgb1; /* the current RGB value for the top-half of the display */
	wire [2:0] rgb2; /* the current RGB value for the bottom-half of the display */

	OSCH #(
		//.NOM_FREQ("7.00")
		//.NOM_FREQ("53.20")
		.NOM_FREQ("133.00")
	) osc (
		.STDBY(1'b0), 
		.OSC(clk_root),
		.SEDSTDBY()
	);

	/* produces a global reset */
	timeout #(
		.COUNTER_WIDTH(4)
	) timeout_global_reset (
		.reset(1'b0),
		.clk_in(clk_root),
		.start(1'b1),
		.value(4'd15),
		.counter(),
		.running(global_reset)
	);

	/* produce a clock for use on the LED matrix */
	clock_divider #(
		.CLK_DIV_WIDTH(2),
		.CLK_DIV_COUNT(3)
	) clkdiv_matrix (
		.reset(global_reset),
		.clk_in(clk_root),
		.clk_out(clk_matrix)
	);

	/* produce signals to scan a 64x32 LED matrix, with 6-bit color */
	matrix_scan matscan1 (
		.reset(global_reset),
		.clk_in(clk_matrix),
		.column_address(column_address),
		.row_address(row_address),
		.row_address_active(row_address_active),
		.clk_pixel_load(clk_pixel_load),
		.clk_pixel(clk_pixel),
		.row_latch(row_latch),
		.output_enable(output_enable),
		.brightness_mask(brightness_mask)
	);

	/* the fetch controller */
	framebuffer_fetch fb_f (
		.reset(global_reset),
		.clk_in(clk_root),

		.column_address(column_address),
		.row_address(row_address),
		.pixel_load_start(clk_pixel_load),

		.ram_data_in(ram_b_data_out),
		.ram_address(ram_b_address),
		.ram_clk_enable(ram_b_clk_enable),
		.ram_reset(ram_b_reset),

		.rgb565_top(pixel_rgb565_top),
		.rgb565_bottom(pixel_rgb565_bottom)
	);

	/* the control module */
	control_module ctrl (
		.reset(global_reset),
		.clk_in(clk_root),

		.uart_rx(uart_rx),
		.rx_running(rx_running),

		.rgb_enable(rgb_enable),

		.ram_data_in(ram_a_data_out),
		.ram_data_out(ram_a_data_in),
		.ram_address(ram_a_address),
		.ram_write_enable(ram_a_write_enable),
		.ram_clk_enable(ram_a_clk_enable),
		.ram_reset(ram_a_reset)
	);

	/* the framebuffer */
	framebuffer fb (
		/* control module interface */
		.DataInA(ram_a_data_in),
		.AddressA(ram_a_address),
		.ClockA(clk_root),
		.ClockEnA(ram_a_clk_enable),
		.WrA(ram_a_write_enable),
		.ResetA(global_reset),
		.QA(ram_a_data_out),

		/* display interface */
		.DataInB(16'b0),
		.AddressB(ram_b_address),
		.ClockB(clk_root),
		.ClockEnB(ram_b_clk_enable),
		.WrB(1'b0),
		.ResetB(ram_b_reset),
		.QB(ram_b_data_out)
	);

	/* split the pixels and get the current brightness' bit */
	pixel_split px_top (
		.pixel_rgb565(pixel_rgb565_top),
		.brightness_mask(brightness_mask),
		.rgb_enable(rgb_enable),
		.rgb_output(rgb1)
	);
	pixel_split px_bottom (
		.pixel_rgb565(pixel_rgb565_bottom),
		.brightness_mask(brightness_mask),
		.rgb_enable(rgb_enable),
		.rgb_output(rgb2)
	);

	/* use this signal for insight! */
	assign debug = 1'b0;

	/* assign signals to pins */
	/* Debug LED  */ assign pin1 = debug;
	/* #OE        */ assign pin2 = ~output_enable;
	/* A / Row[0] */ assign pin3 = row_address_active[0];
	/* B / Row[1] */ assign pin4 = row_address_active[1];
	/* C / Row[2] */ assign pin5 = row_address_active[2];
	/* D / Row[3] */ assign pin6 = row_address_active[3];
	/* Uart Rx    */ assign pin7 = 1'bz; assign uart_rx = pin7;
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
