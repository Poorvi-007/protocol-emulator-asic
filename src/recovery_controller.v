
`default_nettype none

module recovery_controller #(
    parameter integer RESET_CYCLES = 10,
    parameter integer RECOVERY_TIMEOUT = 100,
    parameter integer MAX_ATTEMPTS = 3
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       critical_fault,
    input  wire       recovery_enable,
    input  wire       processor_heartbeat,

    output reg        processor_reset_n,
    output reg        recovery_active,
    output reg        recovery_success,
    output reg        recovery_failed,
    output reg [7:0]  recovery_attempts
);

    localparam IDLE       = 3'd0;
    localparam RESET_HOLD = 3'd1;
    localparam WAIT_ALIVE = 3'd2;
    localparam COMPLETE   = 3'd3;
    localparam FAILED     = 3'd4;

    reg [2:0] state;
    reg [31:0] counter;

    always @(posedge clk) begin
        if (!rst_n) begin
            state             <= IDLE;
            counter           <= 0;
            processor_reset_n <= 1'b1;
            recovery_active   <= 1'b0;
            recovery_success  <= 1'b0;
            recovery_failed   <= 1'b0;
            recovery_attempts <= 0;
        end else begin

            recovery_success <= 1'b0;

            case (state)

                IDLE: begin
                    processor_reset_n <= 1'b1;
                    recovery_active <= 1'b0;

                    if (critical_fault && recovery_enable) begin
                        if (MAX_ATTEMPTS > 0 &&
                            recovery_attempts < MAX_ATTEMPTS) begin
                            recovery_attempts <= recovery_attempts + 1'b1;
                            processor_reset_n <= 1'b0;
                            recovery_active <= 1'b1;
                            counter <= 0;
                            state <= RESET_HOLD;
                        end else begin
                            recovery_failed <= 1'b1;
                            state <= FAILED;
                        end
                    end
                end

                RESET_HOLD: begin
                    processor_reset_n <= 1'b0;
                    recovery_active <= 1'b1;

                    if (counter >= RESET_CYCLES - 1) begin
                        processor_reset_n <= 1'b1;
                        counter <= 0;
                        state <= WAIT_ALIVE;
                    end else begin
                        counter <= counter + 1'b1;
                    end
                end

                WAIT_ALIVE: begin
                    processor_reset_n <= 1'b1;
                    recovery_active <= 1'b1;

                    if (processor_heartbeat) begin
                        recovery_success <= 1'b1;
                        recovery_active <= 1'b0;
                        state <= COMPLETE;
                    end else if (counter >= RECOVERY_TIMEOUT - 1) begin
                        counter <= 0;

                        if (recovery_attempts < MAX_ATTEMPTS) begin
                            recovery_attempts <= recovery_attempts + 1'b1;
                            processor_reset_n <= 1'b0;
                            state <= RESET_HOLD;
                        end else begin
                            recovery_failed <= 1'b1;
                            recovery_active <= 1'b0;
                            state <= FAILED;
                        end
                    end else begin
                        counter <= counter + 1'b1;
                    end
                end

                COMPLETE: begin
                    processor_reset_n <= 1'b1;
                    recovery_active <= 1'b0;

                    if (!critical_fault) begin
                        recovery_attempts <= 0;
                        recovery_failed <= 1'b0;
                        state <= IDLE;
                    end
                end

                FAILED: begin
                    processor_reset_n <= 1'b1;
                    recovery_active <= 1'b0;
                    recovery_failed <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    processor_reset_n <= 1'b1;
                    recovery_active <= 1'b0;
                end

            endcase
        end
    end

endmodule

`default_nettype wire
