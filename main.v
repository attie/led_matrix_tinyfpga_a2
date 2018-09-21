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
	
	wire clk_root;
	wire clk_state;
	
	wire pixel_clk_en;    /* enables the pixel clock */
	wire row_latch_delay; /* delays the row_latch timeout */
	wire row_latch_en;    /* enables the row latch */
	wire output_enable;   /* enables the LEDs */
	
	wire [7:0] column_address; /* the current column */
	reg  [3:0] row_address;    /* the current row */
	
	reg  [5:0] brightness_mask;      /* used to pick a bit from the sub-pixel's brightness */
	reg  [5:0] brightness_mask_prev; /* used to control the timeout once the state has advanced */
	wire [7:0] brightness_timeout;   /* used to time the output enable period */
	
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
	wire global_reset;
	timeout timeout_global_reset (
		.reset(1'b0),
		.clk_in(clk_root),
		.start(1'b1),
		.value(8'd16),
		.counter(),
		.running(global_reset)
	);
	
	/* produces the state-advance clock
	   states produce brighter and brighter pixels before advancing to the next row */
	clock_divider #(
		.CLK_DIV_COUNT('d33) /* 33 * 2 = 66... each row takes 64 pixels, +1 latch = 65 clock cycles */
	) clkdiv_state (
		.reset(global_reset),
		.clk_in(clk_root),
		.clk_out(clk_state)
	);
	
	/* produces the pixel clock enable signal
	   there are 64 pixels per row, this starts immediately after a state advance */
	timeout timeout_pixel_clk_en (
		.reset(global_reset),
		.clk_in(clk_root),
		.start(clk_state),
		.value(8'd64),
		.counter(),
		.running(pixel_clk_en)
	);
	
	/* produce the column address
	   counts from 63 -> 0 and then stops
	   advances out-of-phase with the pixel clock */ 
	timeout timeout_column_address (
		.reset(global_reset),
		.clk_in(~clk_root),
		.start(clk_state),
		.value(8'd63),
		.counter(column_address),
		.running()
	);
	
	/* delays the row latch enable
	   after 63x pixel clocks, we let the latch enable timeout run */
	timeout timeout_row_latch_delay (
		.reset(global_reset),
		.clk_in(clk_root),
		.start(clk_state),
		.value(8'd63),
		.counter(),
		.running(row_latch_delay)
	);
	
	/* produces the row latch enable signal
	   starts once row_latch_delay is complete
	   start is sampled on the rising clk_in edge, thus we get a latch pulse one clock cycle after the last pixel clock */
	timeout timeout_row_latch_en (
		.reset(global_reset),
		.clk_in(clk_root),
		.start(~row_latch_delay),
		.value(8'd1),
		.counter(),
		.running(row_latch_en)
	);
	
	/* decide how long to enable the LEDs for... we probably need some gamma correction here */
	assign brightness_timeout = 
		(brightness_mask_prev == 6'b000001) ? 8'd1 :
		(brightness_mask_prev == 6'b000010) ? 8'd2 :
		(brightness_mask_prev == 6'b000100) ? 8'd4 :
		(brightness_mask_prev == 6'b001000) ? 8'd8 :
		(brightness_mask_prev == 6'b010000) ? 8'd16 :
		(brightness_mask_prev == 6'b100000) ? 8'd32 :
		8'd0;
	
	/* produces the variable-width output enable signal
	   this signal is controlled by the rolling brightness_mask_prev signal (brightness_mask has advanced already)
	   the wider the output_enable pulse, the brighter the LEDs */
	timeout timeout_output_enable (
		.reset(global_reset),
		.clk_in(clk_root),
		.start(~row_latch_en),
		.value(brightness_timeout),
		.counter(),
		.running(output_enable)
	);
	
	/* on completion of the row_latch_delay, we advanced the brightness mask to generate the next row of pixels */
	always @(negedge row_latch_delay) begin
		brightness_mask_prev <= brightness_mask;
		
		if (brightness_mask == 6'd0) begin
			/* catch the initial value / oopsy */
			brightness_mask <= 6'b1;
		end
		else begin
			brightness_mask <= { brightness_mask[4:0], brightness_mask[5] };
		end
	end
	
	/* once the brightness_mask has progressed through the brightest pixel, step the row_address on one */
	always @(negedge brightness_mask_prev[5]) begin
		row_address <= row_address + 4'd1;
	end
	
	/* work out the current column's phase (for the gradient)
	   [0] = blue -> red
	   [1] = green -> blue
	   [2] = red -> green    <-- implicit */
	wire [1:0] column_phase;
	assign column_phase[0] = (column_address < 8'd21);
	assign column_phase[1] = (column_address < 8'd42) && (column_address >= 8'd21);
	//assign column_phase[2] =                             (column_address >= 8'd42);
	
	/* each sub-pixel has a 6-bit brightness value, which depends on the column phase and maths
	   red   --> hi - lo - lo - hi
	   green --> lo - hi - lo - lo
	   blue  --> lo - lo - hi - lo */
	wire [5:0] rgb_red   = column_phase[0] ? ( (8'd21 - column_address) * 'd3 ) : (column_phase[1] ? ( 6'd0                           ) : ( (column_address - 8'd42) * 'd3 ) );
	wire [5:0] rgb_green = column_phase[0] ? ( 6'd0                           ) : (column_phase[1] ? ( (column_address - 8'd21) * 'd3 ) : ( (8'd63 - column_address) * 'd3 ) );
	wire [5:0] rgb_blue  = column_phase[0] ? ( (column_address - 8'd42) * 'd3 ) : (column_phase[1] ? ( (8'd63 - column_address) * 'd3 ) : ( 6'd0                           ) );
	
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
	/* Pixel Clk  */ assign pin10 = clk_root && pixel_clk_en;
	/* Row Latch  */ assign pin11 = clk_root && row_latch_en;
	// 12, 13, 14, 15 ==> JTAG
	/* Red   1    */ assign pin16 = rgb1[0];
	/* Green 1    */ assign pin17 = rgb1[1];
	/* Blue  1    */ assign pin18 = rgb1[2];
	/* Red   2    */ assign pin19 = rgb2[0];
	/* Green 2    */ assign pin20 = rgb2[1];
	/* Blue  2    */ assign pin21 = rgb2[2];
	/*            */ assign pin22 = 1'bz;
endmodule
