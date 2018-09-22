module rainbow_generator (
	input [7:0] column_address,

	output [5:0] red,
	output [5:0] green,
	output [5:0] blue
);
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
	assign red  [5:0] = column_phase[0] ? ( (8'd21 - column_address) * 'd3 ) : (column_phase[1] ? ( 6'd0                           ) : ( (column_address - 8'd42) * 'd3 ) );
	assign green[5:0] = column_phase[0] ? ( 6'd0                           ) : (column_phase[1] ? ( (column_address - 8'd21) * 'd3 ) : ( (8'd63 - column_address) * 'd3 ) );
	assign blue [5:0] = column_phase[0] ? ( (column_address - 8'd42) * 'd3 ) : (column_phase[1] ? ( (8'd63 - column_address) * 'd3 ) : ( 6'd0                           ) );
endmodule
