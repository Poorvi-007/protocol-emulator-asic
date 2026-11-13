`default_nettype none

module uart_timing_generator (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [15:0] divider,
    output reg         sample_tick,
    output reg         baud_tick
);

    reg [15:0] counter;
    reg [3:0]  sample_count;

    always @(posedge clk) begin
        if (!rst_n) begin
            counter      <= 16'd0;
            sample_count <= 4'd0;
            sample_tick  <= 1'b0;
            baud_tick    <= 1'b0;
        end else begin
            sample_tick <= 1'b0;
            baud_tick   <= 1'b0;

            if (!enable) begin
                counter      <= 16'd0;
                sample_count <= 4'd0;
            end else begin
                if (counter >= divider) begin
                    counter     <= 16'd0;
                    sample_tick <= 1'b1;

                    if (sample_count == 4'd15) begin
                        sample_count <= 4'd0;
                        baud_tick    <= 1'b1;
                    end else begin
                        sample_count <= sample_count + 1'b1;
                    end
                end else begin
                    counter <= counter + 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
