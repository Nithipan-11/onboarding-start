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

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : uo_gen
            assign uo_out[i] = en_reg_out_7_0[i]
                ? (en_reg_pwm_7_0[i] ? pwm_out : 1'b1)
                : 1'b0;
        end
        for (i = 0; i < 8; i = i + 1) begin : uio_gen
            assign uio_out[i] = en_reg_out_15_8[i]
                ? (en_reg_pwm_15_8[i] ? pwm_out : 1'b1)
                : 1'b0;
        end
    endgenerate

    assign uio_oe = 8'hFF;

    wire _unused = &{ena, uio_in, 1'b0};

endmodule


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

    // 2-stage synchronizers (CDC)
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

    wire nCS_falling  = nCS_prev  && !nCS_stable;
    wire nCS_rising   = !nCS_prev && nCS_stable;
    wire SCLK_rising  = !SCLK_prev && SCLK_stable;

    // Shift register: capture 16 bits (1 R/W + 7 addr + 8 data)
    reg [15:0] shift_reg;
    reg [4:0]  bit_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 16'b0;
            bit_count <= 5'b0;
        end else if (nCS_falling) begin
            bit_count <= 5'b0;
        end else if (!nCS_stable && SCLK_rising && bit_count < 16) begin
            shift_reg <= {shift_reg[14:0], COPI_stable};
            bit_count <= bit_count + 1;
        end
    end

    // Handshake: transaction_ready -> transaction_processed
    reg        transaction_ready;
    reg        transaction_processed;
    reg [15:0] transaction_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            transaction_ready <= 1'b0;
            transaction_data  <= 16'b0;
        end else if (nCS_rising && bit_count == 16) begin
            transaction_data  <= shift_reg;
            transaction_ready <= 1'b1;
        end else if (transaction_processed) begin
            transaction_ready <= 1'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            transaction_processed <= 1'b0;
            en_reg_out_7_0   <= 8'h00;
            en_reg_out_15_8  <= 8'h00;
            en_reg_pwm_7_0   <= 8'h00;
            en_reg_pwm_15_8  <= 8'h00;
            pwm_duty_cycle   <= 8'h00;
        end else if (transaction_ready && !transaction_processed) begin
            if (transaction_data[15]) begin // write only
                case (transaction_data[14:8])
                    7'h00: en_reg_out_7_0  <= transaction_data[7:0];
                    7'h01: en_reg_out_15_8 <= transaction_data[7:0];
                    7'h02: en_reg_pwm_7_0  <= transaction_data[7:0];
                    7'h03: en_reg_pwm_15_8 <= transaction_data[7:0];
                    7'h04: pwm_duty_cycle  <= transaction_data[7:0];
                    default: ; // invalid address ignored
                endcase
            end
            transaction_processed <= 1'b1;
        end else if (!transaction_ready && transaction_processed) begin
            transaction_processed <= 1'b0;
        end
    end

endmodule
