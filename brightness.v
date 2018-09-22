module brightness (
	input [5:0] value, /* the pixel's absolute value */
	input [5:0] mask,  /* a rolling brightness mask */
	input enable,

	output out
);
	/* apply the brightness mask to the calculated sub-pixel value */
	wire masked_value = (value & mask) != 0;
	assign out = masked_value && enable;
endmodule
