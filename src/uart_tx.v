`default_nettype none

module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       baud_tick,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx,
    output reg        tx_busy
);

    reg [7:0] shift_reg;
    reg [3:0] bit_count;

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;

    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= IDLE;
            shift_reg <= 8'd0;
            bit_count <= 4'd0;
            tx        <= 1'b1;
            tx_busy   <= 1'b0;
        end else begin
            case (state)

                IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;

                    if (tx_start) begin
                        shift_reg <= tx_data;
                        state     <= START;
                        tx_busy   <= 1'b1;
                    end
                end

                START: begin
                    if (baud_tick) begin
                        tx    <= 1'b0;
                        state <= DATA;
                        bit_count <= 4'd0;
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        tx <= shift_reg[0];
                        shift_reg <= {1'b0, shift_reg[7:1]};

                        if (bit_count == 4'd7) begin
                            state <= STOP;
                        end else begin
                            bit_count <= bit_count + 1'b1;
                        end
                    end
                end

                STOP: begin
                    if (baud_tick) begin
                        tx    <= 1'b1;
                        state <= IDLE;
                        tx_busy <= 1'b0;
                    end
                end

                default: begin
                    state   <= IDLE;
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                end

            endcase
        end
    end

endmodule

`default_nettype wire
