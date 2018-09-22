module framebuffer_fetch (
	input reset,
	input clk_in,

	input [5:0] column_address,
	input [3:0] row_address,

	input pixel_load_start,

	input [15:0] ram_data_in,
	output reg [10:0] ram_addr,
	output ram_clk_enable,
	output ram_reset,

	output reg [15:0] rgb565_top,
	output reg [15:0] rgb565_bottom
);

	/* grab data on falling edge of pixel clock */
	wire pixel_load_running;
	wire [3:0] pixel_load_counter;

	assign ram_reset = reset;

	timeout #(
		.COUNTER_WIDTH(3)
	) timeout_pixel_load (
		.reset(reset),
		.clk_in(clk_in),
		.start(pixel_load_start),
		.value(3'd7),
		.counter(pixel_load_counter),
		.running(ram_clk_enable)
	);

	always @(negedge clk_in, posedge reset) begin
		if (reset) begin
			ram_addr <= 11'd0;

			rgb565_top    <= 16'd0;
			rgb565_bottom <= 16'd0;
		end
		else begin
			/* the RAM requires _two_ clock cycles to read... */
			if (pixel_load_counter == 'd7) begin
				/* setup the top-half address */
				ram_addr <= { 1'b0, row_address[3:0], ~column_address[5:0] };
			end
			else if (pixel_load_counter == 'd5) begin
				/* latch the pixel's value */
				rgb565_top <= ram_data_in;
			end
			else if (pixel_load_counter == 'd3) begin
				/* setup the bottom-half address */
				ram_addr <= { 1'b1, row_address[3:0], ~column_address[5:0] };
			end
			else if (pixel_load_counter == 'd1) begin
				/* latch the pixel's value */
				rgb565_bottom <= ram_data_in;
			end
		end
	end
endmodule
