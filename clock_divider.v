/* simple clock divider
   counts from zero to the given value, and then toggles clk_out
	 counts on positive edge of clk_in
	 reset is active-high */
module clock_divider #(
	parameter CLK_DIV_WIDTH = 8,
	parameter CLK_DIV_COUNT = 0
) (
	input reset,
	input clk_in,
	output reg clk_out
);
	reg [CLK_DIV_WIDTH - 1:0] clk_count;

	always @(posedge clk_in, posedge reset) begin
		if (reset) begin
			clk_out <= 1'b0;
			clk_count <= 'b0;
		end
		else begin
			if (clk_count == (CLK_DIV_COUNT - 1)) begin
				clk_out <= ~clk_out;
				clk_count <= 'b0;
			end
			else begin
				clk_count <= clk_count + 'd1;
			end
		end
	end

endmodule