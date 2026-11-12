
`default_nettype none

module timing_generator (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [15:0] divider,
    output reg         tick
);

    reg [15:0] counter;

    always @(posedge clk) begin
        if (!rst_n) begin
            counter <= 16'd0;
            tick    <= 1'b0;
        end else begin
            tick <= 1'b0;

            if (enable) begin
                if (divider == 16'd0) begin
                    counter <= 16'd0;
                    tick    <= 1'b1;
                end else if (counter >= divider - 1'b1) begin
                    counter <= 16'd0;
                    tick    <= 1'b1;
                end else begin
                    counter <= counter + 1'b1;
                end
            end else begin
                counter <= 16'd0;
            end
        end
    end

endmodule

`default_nettype wire
