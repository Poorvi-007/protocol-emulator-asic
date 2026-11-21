`timescale 1ns/1ps

module tb_spaceguard_recovery;

    reg clk = 0;
    reg rst_n = 0;

    reg [7:0] ui_in = 8'h00;
    reg [7:0] uio_in = 8'h00;
    reg ena = 1;

    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    tt_um_protocol_emulator dut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

    always #5 clk = ~clk;

    initial begin
        $display("SPACEGUARD TOP-LEVEL RECOVERY TEST");

        // Test 1: Initial reset
        #20;
        rst_n = 1;
        repeat (5) @(negedge clk);

        if (dut.processor_reset_n !== 1'b1)
            $fatal(1, "FAIL: Processor did not start released");

        $display("PASS: Initial processor startup");

        // Inject a temporary heartbeat failure.
        force dut.execution_progress = 1'b0;

        // Test 2: Watchdog detects missing heartbeat
        wait (dut.watchdog_fault === 1'b1);
        $display("PASS: Watchdog detects missing heartbeat");

        // Restore heartbeat so the processor can recover.
        release dut.execution_progress;

        // Test 3: Recovery controller resets processor
        wait (dut.processor_reset_n === 1'b0);
        $display("PASS: Automatic processor reset asserted");

        wait (dut.processor_reset_n === 1'b1);
        $display("PASS: Processor reset released");

        // Test 4: Processor resumes execution
        wait (dut.recovery_success === 1'b1);
        $display("PASS: Processor heartbeat confirms recovery");

        // Allow the fault-clearing sequence to finish.
        wait (dut.critical_fault === 1'b0);
        repeat (3) @(negedge clk);

        // Test 5: Recovery is re-armed
        if (dut.recovery_attempts !== 8'd0)
            $fatal(1, "FAIL: Recovery attempts were not reset");

        if (dut.recovery_failed !== 1'b0)
            $fatal(1, "FAIL: Recovery incorrectly reported failure");

        $display("PASS: Fault cleared and recovery re-armed");
        $display("ALL SPACEGUARD TOP-LEVEL RECOVERY TESTS PASSED");

        $finish;
    end

    initial begin
        #30000;
        $fatal(1, "FAIL: Top-level recovery test timed out");
    end

endmodule
