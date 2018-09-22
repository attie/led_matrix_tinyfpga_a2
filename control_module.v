module control_module #(
	/* UART configuration */
	parameter UART_CLK_DIV_COUNT = 231, /* 53.2 MHz in / 231 = ~115,200 baud (actually ~115,151 baud, -0.04%) */
	parameter UART_CLK_DIV_WIDTH = 8
) (
	input reset,
	input clk_in,

	input uart_rx,

	output reg [2:0] rgb_enable = 3'b111,

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
			rgb_enable <= 3'b111;
		end
		else if (!uart_rx_invalid) begin
			case (uart_rx_data)
				"R": rgb_enable[0] <= 1'b1;
				"r": rgb_enable[0] <= 1'b0;
				"G": rgb_enable[1] <= 1'b1;
				"g": rgb_enable[1] <= 1'b0;
				"B": rgb_enable[2] <= 1'b1;
				"b": rgb_enable[2] <= 1'b0;
			endcase
		end
	end
endmodule
