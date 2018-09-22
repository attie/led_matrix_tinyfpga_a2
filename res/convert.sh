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

INPUT="${1}"; shift

[ ! -s "${INPUT}" ] && usage "${INPUT}: file not found"

OUTPUT_BASE="${INPUT%%.*}"

# convert input file to a raw framebuffer
gst-launch-1.0 -v \
	filesrc "location=${INPUT}" \
	! decodebin \
	! gamma gamma=0.6 \
	! videoconvert dither=GST_VIDEO_DITHER_NONE \
	! video/x-raw,format=RGB16,width=64,height=32,framerate=0/1 \
	! filesink "location=${OUTPUT_BASE}.bin"

# convert the raw frame buffer to one hex byte per-line for IPexpress
xxd -p -c1 \
	< "${OUTPUT_BASE}.bin" \
	| sed -re 's/^(..)(..)$/\2\n\1/' \
	> "${OUTPUT_BASE}.mem"
