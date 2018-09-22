/* UART is typically 1 start bit, 8 data bits (LSB first), no parity, 1 stop bit
       start, d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7], stop */
module uart_rx #(
	parameter CLK_DIV_COUNT = 30, /* 7 MHz in / 30 = ~115,200 baud (actually ~116,686 baud, +1.29%) */
	parameter CLK_DIV_WIDTH = 5,
	
	parameter DATA_COUNT = 8,
	parameter STOP_COUNT = 1
) (
	input reset,
	input clk_in,

	input rx_line,
	output [DATA_COUNT - 1:0] rx_data,
	output rx_running,
	output rx_invalid
);
	localparam START_COUNT = 1; /* don't change this without a redesign... */
	localparam DATASTOP_COUNT = DATA_COUNT + STOP_COUNT;

	reg [DATASTOP_COUNT - 1:0] rx_bitstream = 'd0;
	assign rx_data[DATA_COUNT - 1:0] = rx_bitstream[DATA_COUNT - 1:0];

	/* if the whole bitstream is a zero, then we're either in a break condition, or something's gone wonky */
	assign rx_invalid = rx_bitstream == 'd0;

	/* hold the clkdiv in reset until rx_line is low (start of frame) AND we're not running (continue until end of frame) */
	wire clkdiv_baudrate_reset = reset || (rx_line && !rx_running);
	wire clk_baudrate;

	/* start the timeout when rx_line is low AND we're not running */
	wire timeout_word_start = !rx_line && !rx_running;

	/* produce a clock that runs at 2x the baudrate
	   this module has to be here so that the divided clock can run in phase with the symbols */
	clock_divider #(
		.CLK_DIV_COUNT(CLK_DIV_COUNT),
		.CLK_DIV_WIDTH(CLK_DIV_WIDTH)
	) clkdiv_baudrate (
		.reset(clkdiv_baudrate_reset),
		.clk_in(clk_in),
		.clk_out(clk_baudrate)
	);

	/* count the bits, and produce sample clock...
	   runs out of phase with the sample clock */
	timeout #(
		.COUNTER_WIDTH(4)
	) timeout_word (
		.reset(reset),
		.clk_in(~clk_baudrate),
		.start(timeout_word_start),
		.value(DATASTOP_COUNT),
		.counter(),
		.running(rx_running)
	);

	/* on each positive edge, clock in a bit
	   the positive edges are approximately in the center of the symbol */
	always @(posedge clk_baudrate, posedge reset) begin
		if (reset) begin
			rx_bitstream <= 'd0;
		end
		else if (rx_running) begin
			rx_bitstream <= { rx_line, rx_bitstream[DATASTOP_COUNT - 1:1] };
		end
	end
endmodule
