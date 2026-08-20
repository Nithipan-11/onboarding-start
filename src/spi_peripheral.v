`default_nettype none

module spi_peripheral (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       SCLK,
    input  wire       COPI,
    input  wire       nCS,
    output reg  [7:0] en_reg_out_7_0,
    output reg  [7:0] en_reg_out_15_8,
    output reg  [7:0] en_reg_pwm_7_0,
    output reg  [7:0] en_reg_pwm_15_8,
    output reg  [7:0] pwm_duty_cycle
);

    reg [1:0] nCS_sync, SCLK_sync, COPI_sync;
    reg       nCS_prev, SCLK_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nCS_sync  <= 2'b11;
            SCLK_sync <= 2'b00;
            COPI_sync <= 2'b00;
            nCS_prev  <= 1'b1;
            SCLK_prev <= 1'b0;
        end else begin
            nCS_sync  <= {nCS_sync[0],  nCS};
            SCLK_sync <= {SCLK_sync[0], SCLK};
            COPI_sync <= {COPI_sync[0], COPI};
            nCS_prev  <= nCS_sync[1];
            SCLK_prev <= SCLK_sync[1];
        end
    end

    wire nCS_stable  = nCS_sync[1];
    wire SCLK_stable = SCLK_sync[1];
    wire COPI_stable = COPI_sync[1];

    wire nCS_rising  = !nCS_prev && nCS_stable;
    wire SCLK_rising = !SCLK_prev && SCLK_stable;

    reg [15:0] shift_reg;
    reg [4:0]  bit_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 16'b0;
            bit_count <= 5'b0;
        end else if (!nCS_stable) begin
            if (SCLK_rising && bit_count < 16) begin
                shift_reg <= {shift_reg[14:0], COPI_stable};
                bit_count <= bit_count + 1;
            end
        end else begin
            bit_count <= 5'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_reg_out_7_0   <= 8'h00;
            en_reg_out_15_8  <= 8'h00;
            en_reg_pwm_7_0   <= 8'h00;
            en_reg_pwm_15_8  <= 8'h00;
            pwm_duty_cycle   <= 8'h00;
        end else if (nCS_rising && bit_count == 16 && shift_reg[15]) begin
            case (shift_reg[14:8])
                7'h00: en_reg_out_7_0  <= shift_reg[7:0];
                7'h01: en_reg_out_15_8 <= shift_reg[7:0];
                7'h02: en_reg_pwm_7_0  <= shift_reg[7:0];
                7'h03: en_reg_pwm_15_8 <= shift_reg[7:0];
                7'h04: pwm_duty_cycle  <= shift_reg[7:0];
                default: ;
            endcase
        end
    end

endmodule
