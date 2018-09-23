module control_module #(
	/* UART configuration */
	//parameter UART_CLK_DIV_COUNT = 30, /* 7 MHz in / 30 = ~115,200 baud (actually ~116,686 baud, +1.29%) */
	parameter UART_CLK_DIV_COUNT = 231, /* 53.2 MHz in / 231 = ~115,200 baud (actually ~115,151 baud, -0.04%) */
	parameter UART_CLK_DIV_WIDTH = 8
) (
	input reset,
	input clk_in,

	input uart_rx,
	output rx_running,

	output reg [2:0] rgb_enable = 3'b111,

	input [7:0] ram_data_in,
	output reg [7:0] ram_data_out,
	output reg [11:0] ram_address,
	output reg ram_write_enable,
	output ram_clk_enable,
	output ram_reset
);
	wire [7:0] uart_rx_data;
	wire uart_rx_running;
	wire uart_rx_invalid;

	reg ram_access_start = 1'b0; /* toggle this to start a write... */
	reg ram_access_start_latch = 1'b0;
	assign ram_reset = reset;

	reg  [1:0]  cmd_line_state = 2'b0;
	reg  [4:0]  cmd_line_addr_row = 5'd0;
	reg  [7:0]  cmd_line_addr_col = 8'd0;
	wire [11:0] cmd_line_addr = { cmd_line_addr_row[4:0], ~cmd_line_addr_col[6:1], cmd_line_addr_col[0] };

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

	timeout #(
		.COUNTER_WIDTH(2)
	) timeout_cmd_line_write (
		.reset(reset),
		.clk_in(~clk_in),
		.start(ram_access_start ^ ram_access_start_latch),
		.value(2'b10),
		.counter(),
		.running(ram_clk_enable)
	);

	assign rx_running = uart_rx_running;

	always @(posedge ram_clk_enable, posedge reset) begin
		if (reset) begin
			ram_access_start_latch <= 1'b0;
		end
		else begin
			ram_access_start_latch <= ram_access_start;
		end
	end

	always @(negedge uart_rx_running, posedge reset) begin
		if (reset) begin
			rgb_enable <= 3'b111;

			ram_data_out <= 8'd0;
			ram_address <= 12'd0;
			ram_write_enable <= 1'b0;
			ram_access_start <= 1'b0;

			cmd_line_state <= 2'd0;
			cmd_line_addr_row <= 5'd0;
			cmd_line_addr_col <= 7'd0;
		end

		/* CMD: Line */
		else if (cmd_line_state == 2'd2) begin
			/* first, get the row to write to */
			cmd_line_addr_row[4:0] <= uart_rx_data[4:0];

			/* and start clocking in the column data
			   64 pixels x 2 bytes each = 128 bytes */
			cmd_line_addr_col[7:0] <= 8'd127;
			cmd_line_state <= 2'd1;
		end
		else if (cmd_line_state == 2'd1) begin
			/* decrement the column address (or finish the load) */
			if (cmd_line_addr_col != 'd0) begin
				cmd_line_addr_col <= cmd_line_addr_col - 'd1;
			end
			else begin
				cmd_line_state <= 2'd0;
			end

			/* store this byte */
			ram_data_out <= uart_rx_data[7:0];
			ram_address <= cmd_line_addr;
			ram_write_enable <= 1'b1;
			ram_access_start <= !ram_access_start;
		end

		/* CMD: Main */
		else if (!uart_rx_invalid) begin
			case (uart_rx_data)
				"R": rgb_enable[0] <= 1'b1;
				"r": rgb_enable[0] <= 1'b0;
				"G": rgb_enable[1] <= 1'b1;
				"g": rgb_enable[1] <= 1'b0;
				"B": rgb_enable[2] <= 1'b1;
				"b": rgb_enable[2] <= 1'b0;
				"L": cmd_line_state <= 2'd2;
			endcase
		end
	end
endmodule
