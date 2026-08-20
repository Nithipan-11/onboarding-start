`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    wire SCLK = ui_in[0];
    wire COPI = ui_in[1];
    wire nCS  = ui_in[2];

    wire [7:0] en_reg_out_7_0;
    wire [7:0] en_reg_out_15_8;
    wire [7:0] en_reg_pwm_7_0;
    wire [7:0] en_reg_pwm_15_8;
    wire [7:0] pwm_duty_cycle;
    wire       pwm_out;

    spi_peripheral spi_inst (
        .clk             (clk),
        .rst_n           (rst_n),
        .SCLK            (SCLK),
        .COPI            (COPI),
        .nCS             (nCS),
        .en_reg_out_7_0  (en_reg_out_7_0),
        .en_reg_out_15_8 (en_reg_out_15_8),
        .en_reg_pwm_7_0  (en_reg_pwm_7_0),
        .en_reg_pwm_15_8 (en_reg_pwm_15_8),
        .pwm_duty_cycle  (pwm_duty_cycle)
    );

    pwm_peripheral pwm_inst (
        .clk            (clk),
        .rst_n          (rst_n),
        .pwm_duty_cycle (pwm_duty_cycle),
        .pwm_out        (pwm_out)
    );

    assign uo_out  = en_reg_out_7_0  & (~en_reg_pwm_7_0  | {8{pwm_out}});
    assign uio_out = en_reg_out_15_8 & (~en_reg_pwm_15_8 | {8{pwm_out}});
    assign uio_oe  = 8'hFF;

    wire _unused = &{ena, uio_in, ui_in[7:3], 1'b0};

endmodule
