module pixel_split (
	input [15:0] pixel_rgb565,
	input [5:0] brightness_mask,
	input [2:0] rgb_enable,

	output [2:0] rgb_output
);
	wire [5:0] red;
	wire [5:0] green;
	wire [5:0] blue;

	/* split the RGB565 pixel into components */
	rgb565 rgb (
		.rgb565(pixel_rgb565),
		.red(red),
		.green(green),
		.blue(blue)
	);

	/* apply the brightness mask to the calculated sub-pixel value */
	brightness b_red (
		.value(red),
		.mask(brightness_mask),
		.enable(rgb_enable[0]),
		.out(rgb_output[0])
	);
	brightness b_green (
		.value(green),
		.mask(brightness_mask),
		.enable(rgb_enable[1]),
		.out(rgb_output[1])
	);
	brightness b_blue(
		.value(blue),
		.mask(brightness_mask),
		.enable(rgb_enable[2]),
		.out(rgb_output[2])
	);
endmodule
