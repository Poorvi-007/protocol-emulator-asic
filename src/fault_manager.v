
`default_nettype none

module fault_manager (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] fault_in,
    input  wire [7:0] fault_enable,
    input  wire       clear_faults,
    output reg  [7:0] fault_status,
    output reg  [1:0] fault_severity,
    output wire       fault_irq,
    output wire       fault_active,
    output wire       critical_fault
);

    // Fault status is latched.
    // New faults always take priority over clearing.
    always @(posedge clk) begin
        if (!rst_n) begin
            fault_status <= 8'b0;
        end
        else begin
            fault_status <=
                (clear_faults ? 8'b0 : fault_status)
                | (fault_in & fault_enable);
        end
    end

    // Severity:
    // 00 = Normal
    // 01 = Warning
    // 10 = Major
    // 11 = Critical

    always @(*) begin
        fault_severity = 2'b00;

        if (fault_status[4] || fault_status[7])
            fault_severity = 2'b01;

        if (fault_status[2] || fault_status[3] ||
            fault_status[5] || fault_status[6])
            fault_severity = 2'b10;

        if (fault_status[0] || fault_status[1])
            fault_severity = 2'b11;
    end

    assign fault_active   = |fault_status;
    assign critical_fault = (fault_severity == 2'b11);
    assign fault_irq      = fault_active;

endmodule

`default_nettype wire
