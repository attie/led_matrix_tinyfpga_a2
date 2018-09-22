module control_module #(
	/* UART configuration */
	parameter UART_CLK_DIV_COUNT = 231, /* 53.2 MHz in / 231 = ~115,200 baud (actually ~115,151 baud, -0.04%) */
	parameter UART_CLK_DIV_WIDTH = 8
) (
	input reset,
	input clk_in,

	input uart_rx,

	output reg enable_red = 1'b1,
	output reg enable_green = 1'b1,
	output reg enable_blue = 1'b1,

	output debug,
	output rx_running
);
	wire [7:0] uart_rx_data;
	wire uart_rx_running;
	wire uart_rx_invalid;

	uart_rx #(
		.CLK_DIV_COUNT(UART_CLK_DIV_COUNT),
		.CLK_DIV_WIDTH(UART_CLK_DIV_WIDTH)
	) urx (
		.reset(reset),
		.clk_in(clk_in),
		.rx_line(uart_rx),
		.rx_data(uart_rx_data),
		.rx_running(uart_rx_running),
		.rx_invalid(uart_rx_invalid)
	);

	assign rx_running = uart_rx_running;

	always @(negedge uart_rx_running, posedge reset) begin
		if (reset) begin
			enable_red   <= 1'b1;
			enable_green <= 1'b1;
			enable_blue  <= 1'b1;
		end
		else if (!uart_rx_invalid) begin
			case (uart_rx_data)
				"R": enable_red   <= 1'b1;
				"r": enable_red   <= 1'b0;
				"G": enable_green <= 1'b1;
				"g": enable_green <= 1'b0;
				"B": enable_blue  <= 1'b1;
				"b": enable_blue  <= 1'b0;
			endcase
		end
	end
endmodule
