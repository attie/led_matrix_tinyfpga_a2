module framebuffer_fetch (
	input reset,
	input clk_in,

	input [5:0] column_address,
	input [3:0] row_address,

	input pixel_load_start,

	input [15:0] ram_data_in,
	output [10:0] ram_address,
	output ram_clk_enable,
	output ram_reset,

	output reg [15:0] rgb565_top,
	output reg [15:0] rgb565_bottom
);

	/* grab data on falling edge of pixel clock */
	wire pixel_load_running;
	wire [3:0] pixel_load_counter;

	reg half_address;
	assign ram_address = { half_address, row_address[3:0], ~column_address[5:0] };

	assign ram_reset = reset;

	timeout #(
		.COUNTER_WIDTH(3)
	) timeout_pixel_load (
		.reset(reset),
		.clk_in(clk_in),
		.start(pixel_load_start),
		.value(3'd3),
		.counter(pixel_load_counter),
		.running(ram_clk_enable)
	);

	always @(negedge clk_in, posedge reset) begin
		if (reset) begin
			half_address <= 1'b0;

			rgb565_top    <= 16'd0;
			rgb565_bottom <= 16'd0;
		end
		else begin
			/* the RAM requires _two_ clock cycles to read...
			   but change the address every clock cycle, so long as we respect the two-cycle fetch */
			if (pixel_load_counter == 'd3) begin
				/* setup the top-half address */
				half_address <= 1'b0;
			end
			else if (pixel_load_counter == 'd2) begin
				/* setup the bottom-half address */
				half_address <= 1'b1;
			end
			else if (pixel_load_counter == 'd1) begin
				/* latch the pixel's value */
				rgb565_top <= ram_data_in;
			end
			else if (pixel_load_counter == 'd0) begin
				/* latch the pixel's value */
				rgb565_bottom <= ram_data_in;
			end
		end
	end
endmodule
