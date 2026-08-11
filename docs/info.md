## How it works

An SPI-controlled peripheral with 16 configurable output pins (uo_out[7:0] and uio_out[7:0]). SPI (SCLK on ui_in[0], COPI on ui_in[1], nCS on ui_in[2]) writes to 5 registers: per-pin output enables (0x00, 0x01), per-pin PWM enables (0x02, 0x03), and a shared PWM duty cycle (0x04). Each output pin is either off, driven high, or driven with a ~3kHz PWM signal depending on its enable/PWM bits.

## How to test

Send 16-bit SPI write transactions (1 R/W bit + 7 address bits + 8 data bits, mode 0) to configure the enable and PWM registers, then observe uo_out/uio_out.

## External hardware

None.
