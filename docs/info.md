## How it works

An 8-bit synchronous counter. When `enable` (ui[0]) is high, the counter increments each clock cycle. When `up_down` (ui[1]) is high, it counts down instead of up. The current count value is output on uo[7:0].

## How to test

Set `ui_in[0] = 1` to enable counting. Set `ui_in[1] = 0` to count up or `1` to count down. Observe `uo_out` incrementing/decrementing each clock cycle. Pull `rst_n` low to reset the counter to 0.

## External hardware

None.
