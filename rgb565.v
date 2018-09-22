module rgb565 (
	input [15:0] rgb565,

	output [5:0] red,
	output [5:0] green,
	output [5:0] blue
);
	/* map out the pixel's data:
	     rrrr rggg  gggb bbbb
	   red and blue are only 5-bit, so we duplicate the LSB to make 6-bit values */
	assign red[5:0]   = { rgb565[15:11], rgb565[11] };
	assign green[5:0] = { rgb565[10:5] };
	assign blue[5:0]  = { rgb565[4:0], rgb565[0] };
endmodule
