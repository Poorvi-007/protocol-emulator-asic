
`timescale 1ns/1ps

module tb_spaceguard_integration;

    reg clk = 0;
    reg rst_n = 0;

    reg heartbeat = 0;
    reg enable = 1;
    reg wait_active = 0;
    reg wait_timeout_active = 0;
    reg clear_fault = 0;

    wire watchdog_fault;

    wire [7:0] fault_status;
    wire [1:0] fault_severity;
    wire fault_irq;
    wire fault_active;
    wire critical_fault;

    wire [7:0] fault_inputs;

    assign fault_inputs = {
        3'b000,
        1'b0,
        3'b000,
        watchdog_fault
    };
    wire [7:0] fault_enable;
    assign fault_enable = 8'hFF;

    watchdog #(
        .HEARTBEAT_TIMEOUT(5),
        .WAIT_TIMEOUT(8)
    ) watchdog_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .heartbeat(heartbeat),
        .wait_active(wait_active),
        .wait_timeout_active(wait_timeout_active),
        .clear_fault(clear_fault),
        .fault(watchdog_fault)
    );

    fault_manager fault_manager_inst (
        .clk(clk),
        .rst_n(rst_n),
        .fault_in(fault_inputs),
        .fault_enable(fault_enable),
        .clear_faults(1'b0),
        .fault_status(fault_status),
        .fault_severity(fault_severity),
        .fault_irq(fault_irq),
        .fault_active(fault_active),
        .critical_fault(critical_fault)
    );

    always #5 clk = ~clk;

    initial begin

        // Test 1: Reset
        #12;
        rst_n = 1;
        @(negedge clk);
        #1;

        if (fault_irq !== 0 || fault_status !== 0)
            $fatal(1, "FAIL: Reset");

        $display("PASS: Reset");

        // Test 2: Watchdog detects missing heartbeat
        repeat (6) @(negedge clk);
        #1;

        if (watchdog_fault !== 1)
            $fatal(1, "FAIL: Watchdog detection");

        $display("PASS: Watchdog detects timeout");

        // Test 3: Fault Manager records watchdog fault
        if (fault_status !== 8'h01)
            $fatal(1, "FAIL: Fault not recorded");

        $display("PASS: Fault recorded");

        // Test 4: Critical severity
        if (fault_severity !== 2'b11)
            $fatal(1, "FAIL: Critical severity");

        $display("PASS: Critical severity");

        // Test 5: Fault IRQ
        if (fault_irq !== 1 || fault_active !== 1 ||
            critical_fault !== 1)
            $fatal(1, "FAIL: Fault outputs");

        $display("PASS: Fault IRQ and critical output");

        // Test 6: Fault remains latched
        if (fault_status !== 8'h01)
            $fatal(1, "FAIL: Fault not latched");

        $display("PASS: Fault remains latched");

        $display("ALL SPACEGUARD INTEGRATION TESTS PASSED");

        $finish;
    end

endmodule
