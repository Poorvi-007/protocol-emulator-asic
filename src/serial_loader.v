`default_nettype none

module serial_loader (
    input wire        clk,
    input wire        rst_n,

    input wire        serial_in,
    input wire        serial_valid,

    output reg        load_en,
    output reg [3:0]  load_addr,
    output reg [15:0] load_data
);

    reg [4:0] bit_count;
    reg [15:0] shift_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            bit_count  <= 5'd0;
            shift_reg  <= 16'd0;
            load_en    <= 1'b0;
            load_addr  <= 4'd0;
            load_data  <= 16'd0;
        end else begin
            load_en <= 1'b0;

            if (serial_valid) begin
                shift_reg <= {shift_reg[14:0], serial_in};

                if (bit_count == 5'd15) begin
                    load_data  <= {shift_reg[14:0], serial_in};
                    load_en    <= 1'b1;
                    load_addr  <= load_addr + 1'b1;
                    bit_count  <= 5'd0;
                end else begin
                    bit_count <= bit_count + 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
