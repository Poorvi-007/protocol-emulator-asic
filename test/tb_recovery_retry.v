
`timescale 1ns/1ps

module tb_recovery_retry;

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
        .RESET_CYCLES(2),
        .RECOVERY_TIMEOUT(4),
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

    integer cycle;

    initial begin

        // Test 1: Initial reset
        #12;
        rst_n = 1;
        critical_fault = 1;

        // Test 2: Wait for three recovery attempts
        for (cycle = 0; cycle < 40; cycle = cycle + 1) begin
            @(negedge clk);
            #1;
        end

        if (recovery_attempts !== 3)
            $fatal(1, "FAIL: Expected three attempts");

        $display("PASS: Three recovery attempts completed");

        // Test 3: Recovery failure
        if (recovery_failed !== 1)
            $fatal(1, "FAIL: Recovery failure not reported");

        $display("PASS: Permanent failure reported");

        // Test 4: Processor reset released after failure
        if (processor_reset_n !== 1)
            $fatal(1, "FAIL: Processor reset remains active");

        $display("PASS: Processor reset released after failure");

        // Test 5: No additional recovery attempts
        repeat (10) @(negedge clk);
        #1;

        if (recovery_attempts !== 3)
            $fatal(1, "FAIL: More than three attempts");

        $display("PASS: No fourth recovery attempt");

        $display("ALL RECOVERY RETRY TESTS PASSED");

        $finish;
    end

endmodule
