`default_nettype none

module uart_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    input  wire       sample_tick,
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    output reg        framing_error,
    output reg        rx_busy
);

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [3:0] sample_count;
    reg [2:0] bit_count;
    reg [7:0] shift_reg;

    reg rx_sync1;
    reg rx_sync2;

    always @(posedge clk) begin
        if (!rst_n) begin
            state         <= IDLE;
            sample_count  <= 4'd0;
            bit_count     <= 3'd0;
            shift_reg     <= 8'd0;
            rx_data       <= 8'd0;
            rx_valid      <= 1'b0;
            framing_error <= 1'b0;
            rx_busy       <= 1'b0;
            rx_sync1      <= 1'b1;
            rx_sync2      <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
            rx_valid <= 1'b0;

            if (sample_tick) begin
                case (state)

                    IDLE: begin
                        rx_busy <= 1'b0;
                        if (!rx_sync2) begin
                            state        <= START;
                            sample_count <= 4'd0;
                            rx_busy      <= 1'b1;
                        end
                    end

                    START: begin
                        if (sample_count == 4'd7) begin
                            if (!rx_sync2) begin
                                sample_count <= 4'd0;
                                bit_count    <= 3'd0;
                                state        <= DATA;
                            end else begin
                                state   <= IDLE;
                                rx_busy <= 1'b0;
                            end
                        end else begin
                            sample_count <= sample_count + 1'b1;
                        end
                    end

                    DATA: begin
                        if (sample_count == 4'd15) begin
                            sample_count <= 4'd0;
                            shift_reg <= {rx_sync2, shift_reg[7:1]};

                            if (bit_count == 3'd7)
                                state <= STOP;
                            else
                                bit_count <= bit_count + 1'b1;
                        end else begin
                            sample_count <= sample_count + 1'b1;
                        end
                    end

                    STOP: begin
                        if (sample_count == 4'd15) begin
                            sample_count  <= 4'd0;
                            rx_data       <= shift_reg;
                            rx_valid      <= 1'b1;
                            framing_error <= !rx_sync2;
                            state         <= IDLE;
                            rx_busy       <= 1'b0;
                        end else begin
                            sample_count <= sample_count + 1'b1;
                        end
                    end

                    default: begin
                        state   <= IDLE;
                        rx_busy <= 1'b0;
                    end

                endcase
            end
        end
    end

endmodule

`default_nettype wire
