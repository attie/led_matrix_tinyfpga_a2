#!/bin/bash -eu

usage() {
	{
		while [ $# -gt 0 ]; do
			echo "${1}"
			shift
		done
		echo "usage:"
		echo "    ${0} <input file>"
	} >&2
	exit 1
}

[ $# -ne 1 ] && usage

INPUT="$(readlink -e "${1}")"; shift

[ ! -s "${INPUT}" ] && usage "${INPUT}: file not found"

[ "$(file --brief --mime-type "${INPUT}" | cut -d / -f1)" != "image" ] && usage "${INPUT}: not an image file"

OUTPUT_DIR="${INPUT%/*}"
OUTPUT_NAME="${INPUT##*/}"
OUTPUT_BASE="${OUTPUT_NAME%.*}"

# convert input file to a raw framebuffer
gst-launch-1.0 -v \
	filesrc "location=${INPUT}" \
	! decodebin \
	! gamma gamma=0.4 \
	! videoconvert dither=GST_VIDEO_DITHER_NONE \
	! video/x-raw,format=RGB16,width=64,height=32,framerate=0/1 \
	! filesink "location=${OUTPUT_DIR}/.${OUTPUT_BASE}.bin"

# convert the raw frame buffer to one hex byte per-line for IPexpress
xxd -p -c1 \
	< "${OUTPUT_DIR}/.${OUTPUT_BASE}.bin" \
	> "${OUTPUT_DIR}/${OUTPUT_BASE}.mem"

# convert the raw frame buffer to lines to be sent via UART
xxd -p -c$((64 * 2)) \
	< "${OUTPUT_DIR}/.${OUTPUT_BASE}.bin" \
	| sed -re 's/(..)(..)/\2\1/g' \
	| awk '{printf "4C%02x%s\n", NR-1, $0}' \
	| xxd -r -p \
	> "${OUTPUT_DIR}/${OUTPUT_BASE}.uart"
