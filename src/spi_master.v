`default_nettype none

module spi_master (
    input  wire       clk,
    input  wire       rst_n,

    input  wire       start,
    input  wire [7:0] tx_data,
    input  wire [7:0] divider,
    input  wire [1:0] spi_mode,

    input  wire       miso,

    output reg        sclk,
    output reg        mosi,
    output reg        cs_n,

    output reg  [7:0] rx_data,
    output reg        busy,
    output reg        done
);

    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [7:0] divider_count;
    reg [3:0] bit_count;
    reg       half_cycle;

    wire cpol = spi_mode[1];
    wire cpha = spi_mode[0];

    always @(posedge clk) begin
        if (!rst_n) begin
            sclk          <= 1'b0;
            mosi          <= 1'b0;
            cs_n          <= 1'b1;
            rx_data       <= 8'd0;
            tx_shift      <= 8'd0;
            rx_shift      <= 8'd0;
            divider_count <= 8'd0;
            bit_count     <= 4'd0;
            half_cycle    <= 1'b0;
            busy          <= 1'b0;
            done          <= 1'b0;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                if (start) begin
                    tx_shift      <= tx_data;
                    rx_shift      <= 8'd0;
                    divider_count <= 8'd0;
                    bit_count     <= 4'd0;
                    half_cycle    <= 1'b0;

                    sclk <= cpol;
                    cs_n <= 1'b0;
                    busy <= 1'b1;

                    if (cpha)
                        mosi <= 1'b0;
                    else
                        mosi <= tx_data[7];
                end
            end else begin
                if (divider_count >= divider) begin
                    divider_count <= 8'd0;

                    if (!half_cycle) begin
                        // Leading SPI clock edge
                        sclk       <= ~sclk;
                        half_cycle <= 1'b1;

                        if (cpha) begin
                            // CPHA=1: change data on leading edge
                            mosi     <= tx_shift[7];
                            tx_shift <= {tx_shift[6:0], 1'b0};
                        end else begin
                            // CPHA=0: sample data on leading edge
                            rx_shift <= {rx_shift[6:0], miso};
                        end
                    end else begin
                        // Trailing SPI clock edge
                        sclk       <= cpol;
                        half_cycle <= 1'b0;

                        if (cpha) begin
                            // CPHA=1: sample data on trailing edge
                            rx_shift <= {rx_shift[6:0], miso};
                        end else begin
                            // CPHA=0: change data on trailing edge
                            tx_shift <= {tx_shift[6:0], 1'b0};
                            mosi     <= tx_shift[6];
                        end

                        if (bit_count == 4'd7) begin
                            if (cpha)
                                rx_data <= {rx_shift[6:0], miso};
                            else
                                rx_data <= rx_shift;

                            busy <= 1'b0;
                            done <= 1'b1;
                            cs_n <= 1'b1;
                            sclk <= cpol;
                        end else begin
                            bit_count <= bit_count + 1'b1;
                        end
                    end
                end else begin
                    divider_count <= divider_count + 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
