`default_nettype none

module pwm_peripheral (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] pwm_duty_cycle,
    output reg        pwm_out
);

    // 10 MHz clk / 3 kHz target ≈ 3334 cycles per PWM period
    localparam PWM_PERIOD = 3334;

    reg [11:0] counter;
    reg [11:0] threshold;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            counter <= 12'd0;
        else if (counter >= PWM_PERIOD - 1)
            counter <= 12'd0;
        else
            counter <= counter + 1;
    end

    always @(*) begin
        threshold = (pwm_duty_cycle * PWM_PERIOD) >> 8;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_out <= 1'b0;
        else if (pwm_duty_cycle == 8'hFF)
            pwm_out <= 1'b1;
        else
            pwm_out <= (counter < threshold) ? 1'b1 : 1'b0;
    end

endmodule
