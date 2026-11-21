
`timescale 1ns/1ps

module tb_watchdog;

    reg clk = 0;
    reg rst_n = 0;
    reg enable = 1;
    reg heartbeat = 0;
    reg wait_active = 0;
    reg wait_timeout_active = 0;
    reg clear_fault = 0;

    wire fault;

    watchdog #(
        .HEARTBEAT_TIMEOUT(5),
        .WAIT_TIMEOUT(8)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .heartbeat(heartbeat),
        .wait_active(wait_active),
        .wait_timeout_active(wait_timeout_active),
        .clear_fault(clear_fault),
        .fault(fault)
    );

    always #5 clk = ~clk;

    task check_fault;
        input expected;
        begin
            #1;
            if (fault !== expected) begin
                $display("FAIL: expected=%b actual=%b",
                         expected, fault);
                $fatal(1);
            end
            else begin
                $display("PASS: fault=%b", fault);
            end
        end
    endtask

    initial begin

        // Test 1: Reset
        #12;
        check_fault(0);
        rst_n = 1;

        // Test 2: Heartbeat timeout
        repeat (6) @(negedge clk);
        check_fault(1);

        // Test 3: Clear fault
        clear_fault = 1;
        @(negedge clk);
        clear_fault = 0;
        check_fault(0);

        // Test 4: Heartbeat prevents timeout
        heartbeat = 1;
        repeat (8) @(negedge clk);
        heartbeat = 0;
        check_fault(0);

        // Test 5: Wait timeout
        wait_active = 1;
        wait_timeout_active = 1;
        repeat (9) @(negedge clk);
        check_fault(1);

        // Test 6: Clear after wait timeout
        clear_fault = 1;
        @(negedge clk);
        clear_fault = 0;
        wait_active = 0;
        wait_timeout_active = 0;
        check_fault(0);

        // Test 7: Disabled watchdog
        enable = 0;
        repeat (10) @(negedge clk);
        check_fault(0);

        $display("ALL WATCHDOG TESTS PASSED");
        $finish;
    end

endmodule
