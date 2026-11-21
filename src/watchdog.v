
`default_nettype none

module watchdog #(
    parameter integer HEARTBEAT_TIMEOUT = 1000,
    parameter integer WAIT_TIMEOUT = 100000
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire heartbeat,
    input wire wait_active,
    input wire wait_timeout_active,
    input wire clear_fault,
    output reg fault
);

    reg [31:0] heartbeat_counter;
    reg [31:0] wait_counter;

    always @(posedge clk) begin
        if (!rst_n) begin
            heartbeat_counter <= 0;
            wait_counter <= 0;
            fault <= 0;
        end
        else if (clear_fault) begin
            heartbeat_counter <= 0;
            wait_counter <= 0;
            fault <= 0;
        end
        else if (!enable) begin
            heartbeat_counter <= 0;
            wait_counter <= 0;
        end
        else if (!fault) begin

            if (wait_active)
                heartbeat_counter <= 0;
            else if (heartbeat)
                heartbeat_counter <= 0;
            else if (heartbeat_counter >= HEARTBEAT_TIMEOUT - 1)
                fault <= 1;
            else
                heartbeat_counter <= heartbeat_counter + 1;

            if (wait_timeout_active) begin
                if (wait_counter >= WAIT_TIMEOUT - 1)
                    fault <= 1;
                else
                    wait_counter <= wait_counter + 1;
            end
            else begin
                wait_counter <= 0;
            end

        end
    end

endmodule

`default_nettype wire
