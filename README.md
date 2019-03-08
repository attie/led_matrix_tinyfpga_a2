# RGB Matrix

This project aims to run a 64 &times; 32 RGB LED matrix from a [TinyFPGA AX2](https://store.tinyfpga.com/products/tinyfpga-a2), with two full RGB565 framebuffers (double buffering), and a UART interface.

## Key Features

  - Internal RGB565 framebuffer (16-bit color)
  - Double buffered (no tearing)
  - UART interface allowing 30 fps
  - Solid display (no flicker)

### RGB565 Framebuffer

Due to memory constraints, I'm aiming to have a 16-bit framebuffer.
Each pixel will require 2 bytes, and the layout will be as follows:

```
R4 R3 R2 R1  R0 G5 G4 G3    G2 G1 G0 B4  B3 B2 B1 B0
```

To display this correctly, I'll need to be able to control the brightness of each LED with a range of at least 6-bits.

As mentioned above, the Embedded Block RAM (EBR) available in a TinyFPGA's MachXO2-1200 is 64-kbit.

Frame size:

  - _width_ &times; _height_ &times; _color_depth_ = _bits_per_frame_
  - 64 &times; 32 &times; 16 = 32,768 bits

Two frames:

  - 32,768 &times; 2 = 65,536 bits... perfect

### Double Buffered

To ensure that the display is pristine and doesn't have _any_ tearing, I plan to provide two buffers.

The FPGA can be rendering from buffer A, while the host is writing new data into buffer B.
Once the new buffer is ready, the FPGA can switch and render from B, while the host writes to A.

The switch can be synchronised to the vertical sync.

### UART Interface

I'd _really_ like to be able to update the display at ~30 fps.

With a UART, the frame has 1&times; start bit, 8&times; data bits, and 1&times; stop bit - thus 10 symbols per byte, or **20** symbols per pixel.
There is also likely to be some idle-time between frames, so adding a 10% margin is sensible.

A quick bit of maths implies that this should be possible with a baudrate of &lt; 1.5 Mbit/s.

  - _width_ &times; _height_ &times; _symbols_per_pixel_ &times; _frame_rate_ &times; _margin_ = _bits_per_second_
  - 64 &times; 32 &times; 20 &times; 30 &times; 1.1 = 1,351,680 bit/sec

A baudrate of ~2 Mbit/s should be easy enough to work with, and should provide ample headroom.

### Solid Display

The LED matrix is driven fast enough that each row is rendered beyond what is troubling to the human eye - something that seriously bugs me.
This means that glancing away or past the display won't leave flickering streaks - somewhat like Dianna outlines in her "[The Projector Illusion](https://www.youtube.com/watch?v=Xp6bxCh_p7c)" video.

To keep up with this, the display must be rendered from internal memory, and cannot feasably be driven directly via the UART.

## Implementation Details

I've written more about the implementation of varios parts of the project on their own pages:

  - [RGB LED Matrix Module Overview](doc/led_matrix_overview.md)
  - [Driving the LED Matrix](doc/led_matrix_driving.md)
  - [UART Interface](doc/uart_rx.md)
  - Memory Storage (_coming soon_)
