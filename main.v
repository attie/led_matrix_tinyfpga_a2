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

	wire uart_rx;

	wire [5:0] column_address;
	wire [3:0] row_address;
	wire [3:0] row_address_active;
	wire [5:0] brightness_mask;

	wire [2:0] rgb_enable;
	wire [2:0] rgb1; /* the current RGB value for the top-half of the display */
	wire [2:0] rgb2; /* the current RGB value for the bottom-half of the display */

	OSCH #(
		.NOM_FREQ("53.20")
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

	clock_divider #(
		.CLK_DIV_WIDTH(3),
		.CLK_DIV_COUNT(4)
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

	/* grab data on falling edge of pixel clock */
	wire pixel_load_running;
	wire [3:0] pixel_load_counter;
	wire [15:0] pixel_rgb565_read;
	reg [15:0] pixel_rgb565_top;
	reg [15:0] pixel_rgb565_bottom;
	reg [10:0] ram_addr = 'd0;

	timeout #(
		.COUNTER_WIDTH(3)
	) timeout_pixel_load (
		.reset(global_reset),
		.clk_in(clk_root),
		.start(clk_pixel_load),
		.value(3'd7),
		.counter(pixel_load_counter),
		.running(pixel_load_running)
	);

	always @(negedge clk_root) begin
		/* the RAM requires _two_ clock cycles to read... */
		if (pixel_load_counter == 'd7) begin
			/* setup the top-half address */
			ram_addr <= { 1'b0, row_address[3:0], ~column_address[5:0] };
		end
		else if (pixel_load_counter == 'd5) begin
			/* latch the pixel's value */
			pixel_rgb565_top <= pixel_rgb565_read;
		end
		else if (pixel_load_counter == 'd3) begin
			/* setup the bottom-half address */
			ram_addr <= { 1'b1, row_address[3:0], ~column_address[5:0] };
		end
		else if (pixel_load_counter == 'd1) begin
			/* latch the pixel's value */
			pixel_rgb565_bottom <= pixel_rgb565_read;
		end
	end

	/* the framebuffer */
	framebuffer fb (
		.DataInA(8'b0),
		.DataInB(16'b0),
		.AddressA(12'b0),
		.AddressB(ram_addr),
		.ClockA(1'b0),
		.ClockB(clk_root),
		.ClockEnA(1'b0),
		.ClockEnB(pixel_load_running),
		.WrA(1'b0),
		.WrB(1'b0),
		.ResetA(global_reset),
		.ResetB(global_reset),
		.QA(),
		.QB(pixel_rgb565_read)
	);

	/* the control module */
	control_module ctrl (
		.reset(global_reset),
		.clk_in(clk_root),
		.uart_rx(uart_rx),
		.rgb_enable(rgb_enable),
		.rx_running(rx_running)
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
