`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // High when design is powered and selected
    input  wire       clk,      // Clock
    input  wire       rst_n     // Reset (active low)
);

    reg [7:0] count;

    // ui_in[0] = enable counting
    // ui_in[1] = 0 for count up, 1 for count down
    always @(posedge clk) begin
        if (!rst_n) begin
            count <= 8'b0;
        end else if (ena && ui_in[0]) begin
            if (ui_in[1])
                count <= count - 1;
            else
                count <= count + 1;
        end
    end

    assign uo_out  = count;
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // List unused inputs to prevent warnings
    wire _unused = &{ui_in[7:2], uio_in, 1'b0};

endmodule
