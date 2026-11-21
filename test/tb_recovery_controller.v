
`timescale 1ns/1ps

module tb_recovery_controller;

    reg clk = 0;
    reg rst_n = 0;
    reg critical_fault = 0;
    reg recovery_enable = 1;
    reg processor_heartbeat = 0;

    wire processor_reset_n;
    wire recovery_active;
    wire recovery_success;
    wire recovery_failed;
    wire [7:0] recovery_attempts;

    recovery_controller #(
        .RESET_CYCLES(3),
        .RECOVERY_TIMEOUT(6),
        .MAX_ATTEMPTS(3)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .critical_fault(critical_fault),
        .recovery_enable(recovery_enable),
        .processor_heartbeat(processor_heartbeat),
        .processor_reset_n(processor_reset_n),
        .recovery_active(recovery_active),
        .recovery_success(recovery_success),
        .recovery_failed(recovery_failed),
        .recovery_attempts(recovery_attempts)
    );

    always #5 clk = ~clk;

    initial begin

        // Test 1: Reset
        #12;
        if (processor_reset_n !== 1 ||
            recovery_attempts !== 0)
            $fatal(1, "FAIL: Initial reset");

        $display("PASS: Initial reset");

        rst_n = 1;

        // Test 2: Critical fault triggers recovery
        @(negedge clk);
        critical_fault = 1;

        @(negedge clk);
        #1;

        if (processor_reset_n !== 0 ||
            recovery_active !== 1 ||
            recovery_attempts !== 1)
            $fatal(1, "FAIL: Recovery trigger");

        $display("PASS: Critical fault triggers recovery");

        // Test 3: Reset is released after three cycles
        repeat (3) @(negedge clk);
        #1;

        if (processor_reset_n !== 1)
            $fatal(1, "FAIL: Reset release");

        $display("PASS: Processor reset released");

        // Test 4: Heartbeat confirms recovery
        processor_heartbeat = 1;
        @(negedge clk);
        #1;

        if (recovery_success !== 1)
            $fatal(1, "FAIL: Recovery success");

        $display("PASS: Heartbeat confirms recovery");

        // Return heartbeat low
        processor_heartbeat = 0;

        // Test 5: Clear fault and re-arm
        critical_fault = 0;
        @(negedge clk);
        @(negedge clk);
        #1;

        if (recovery_attempts !== 0 ||
            recovery_failed !== 0)
            $fatal(1, "FAIL: Recovery re-arm");

        $display("PASS: Recovery re-armed");

        // Test 6: Disable recovery
        recovery_enable = 0;
        critical_fault = 1;
        @(negedge clk);
        #1;

        if (recovery_attempts !== 0 ||
            processor_reset_n !== 1)
            $fatal(1, "FAIL: Recovery disable");

        $display("PASS: Recovery disable");

        $display("ALL RECOVERY CONTROLLER TESTS PASSED");

        $finish;
    end

endmodule
