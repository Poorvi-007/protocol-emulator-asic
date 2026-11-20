
`timescale 1ns/1ps

module tb_fault_manager;

    reg clk = 0;
    reg rst_n = 0;
    reg [7:0] fault_in = 0;
    reg [7:0] fault_enable = 8'hFF;
    reg clear_faults = 0;

    wire [7:0] fault_status;
    wire [1:0] fault_severity;
    wire fault_irq;
    wire fault_active;
    wire critical_fault;

    fault_manager dut (
        .clk(clk),
        .rst_n(rst_n),
        .fault_in(fault_in),
        .fault_enable(fault_enable),
        .clear_faults(clear_faults),
        .fault_status(fault_status),
        .fault_severity(fault_severity),
        .fault_irq(fault_irq),
        .fault_active(fault_active),
        .critical_fault(critical_fault)
    );

    always #5 clk = ~clk;

    task check;
        input [7:0] expected_status;
        input [1:0] expected_severity;
        begin
            #1;
            if (fault_status !== expected_status ||
                fault_severity !== expected_severity) begin
                $display("FAIL: status=%h severity=%b",
                         fault_status, fault_severity);
                $fatal(1);
            end
            else begin
                $display("PASS: status=%h severity=%b",
                         fault_status, fault_severity);
            end
        end
    endtask

    initial begin
        // Reset
        #12;
        check(8'h00, 2'b00);

        rst_n = 1;
        @(negedge clk);

        // F4: UART framing warning
        fault_in = 8'h10;
        @(negedge clk);
        fault_in = 0;
        check(8'h10, 2'b01);

        // F3: SPI timeout, major
        fault_in = 8'h08;
        @(negedge clk);
        fault_in = 0;
        check(8'h18, 2'b10);

        // F0: Watchdog timeout, critical
        fault_in = 8'h01;
        @(negedge clk);
        fault_in = 0;
        check(8'h19, 2'b11);

        // Clear all inactive faults
        clear_faults = 1;
        @(negedge clk);
        clear_faults = 0;
        check(8'h00, 2'b00);

        // Disabled fault must not latch
        fault_enable = 8'hFB;
        fault_in = 8'h04;
        @(negedge clk);
        fault_in = 0;
        check(8'h00, 2'b00);

        // New fault must survive simultaneous clear
        fault_enable = 8'hFF;
        fault_in = 8'h10;
        clear_faults = 1;
        @(negedge clk);
        fault_in = 0;
        clear_faults = 0;
        check(8'h10, 2'b01);

        if (fault_irq !== 1'b1 || fault_active !== 1'b1 ||
            critical_fault !== 1'b0)
            $fatal(1, "FAIL: output signals incorrect");

        $display("ALL FAULT MANAGER TESTS PASSED");
        $finish;
    end

endmodule
