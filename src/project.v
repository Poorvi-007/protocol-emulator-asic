
/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_protocol_emulator (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // Processor and GPIO
    wire [7:0] gpio_out;
    wire [7:0] timing_divider;
    wire timing_tick;

    // SpaceGuard watchdog
    wire execution_progress;
    wire wait_active;
    wire wait_timeout_active;
    wire processor_alive;
    wire watchdog_fault;

    // SpaceGuard recovery signals
    wire processor_reset_n;
    wire subsystem_reset_n;
    wire recovery_active;
    wire recovery_success;
    wire recovery_failed;
    wire [7:0] recovery_attempts;

    // Sequenced fault-clear controls
    reg watchdog_clear;
    reg fault_clear;

    // Sequencer for safely clearing recovered faults.
    localparam CLEAR_IDLE = 2'd0;
    localparam CLEAR_WATCHDOG = 2'd1;
    localparam CLEAR_FAULTS = 2'd2;

    reg [1:0] clear_state;

    // Processor subsystem reset; SpaceGuard protection stays active.
    assign subsystem_reset_n = rst_n & processor_reset_n;

    // Clear watchdog first, then clear the recorded fault.
    always @(posedge clk) begin
        if (!rst_n) begin
            clear_state <= CLEAR_IDLE;
            watchdog_clear <= 1'b0;
            fault_clear <= 1'b0;
        end else begin
            watchdog_clear <= 1'b0;
            fault_clear <= 1'b0;

            case (clear_state)
                CLEAR_IDLE: begin
                    if (recovery_success)
                        clear_state <= CLEAR_WATCHDOG;
                end

                CLEAR_WATCHDOG: begin
                    watchdog_clear <= 1'b1;
                    clear_state <= CLEAR_FAULTS;
                end

                CLEAR_FAULTS: begin
                    if (!watchdog_fault) begin
                        fault_clear <= 1'b1;
                        clear_state <= CLEAR_IDLE;
                    end
                end

                default: begin
                    clear_state <= CLEAR_IDLE;
                end
            endcase
        end
    end

    // SpaceGuard Fault Manager
    wire [7:0] fault_status;
    wire [1:0] fault_severity;
    wire fault_irq;
    wire fault_active;
    wire critical_fault;

    wire [7:0] fault_inputs;
    wire [7:0] fault_enable;

    // Programming interface
    wire load_en;
    wire [3:0] load_addr;
    wire [15:0] load_data;
    wire program_mode;

    // UART signals
    wire [7:0] uart_rx_data;
    wire uart_rx_valid;
    wire uart_rx_framing_error;
    wire uart_rx_busy;

    wire [7:0] uart_tx_data;
    wire uart_tx_start;
    wire uart_tx_busy;
    wire uart_tx_line;

    wire [15:0] uart_sample_divider;
    wire uart_sample_tick;
    wire uart_baud_tick;

    // SPI signals
    wire [7:0] spi_rx_data;
    wire spi_busy;
    wire spi_done;
    wire [7:0] spi_tx_data;
    wire [7:0] spi_divider;
    wire [1:0] spi_mode;
    wire spi_start;

    wire spi_sclk;
    wire spi_mosi;
    wire spi_cs_n;

    assign program_mode = ui_in[2];

    // Initial implemented fault sources:
    // F0 = Watchdog timeout (critical)
    // F4 = UART framing error (warning)
    // Other channels reserved until detectors are implemented.
    assign fault_inputs = {
        3'b000,
        uart_rx_framing_error,
        3'b000,
        watchdog_fault
    };

    assign fault_enable = 8'hFF;

    // Serial program loader
    serial_loader loader (
        .clk(clk),
        .rst_n(rst_n),
        .serial_in(ui_in[0]),
        .serial_valid(ui_in[1]),
        .load_en(load_en),
        .load_addr(load_addr),
        .load_data(load_data)
    );

    // Main protocol controller
    protocol_core core (
        .clk(clk),
        .rst_n(subsystem_reset_n),
        .gpio_in(ui_in),
        .gpio_out(gpio_out),
        .timing_divider(timing_divider),
        .load_en(load_en),
        .load_addr(load_addr),
        .load_data(load_data),
        .program_mode(program_mode),
        .timing_tick(timing_tick),

        // UART connections
        .uart_rx_data(uart_rx_data),
        .uart_rx_valid(uart_rx_valid),
        .uart_rx_framing_error(uart_rx_framing_error),
        .uart_rx_busy(uart_rx_busy),
        .uart_tx_busy(uart_tx_busy),
        .uart_tx_data(uart_tx_data),
        .uart_tx_start(uart_tx_start),
        .uart_sample_divider(uart_sample_divider),

        // SPI connections
        .spi_rx_data(spi_rx_data),
        .spi_busy(spi_busy),
        .spi_done(spi_done),
        .spi_tx_data(spi_tx_data),
        .spi_divider(spi_divider),
        .spi_mode(spi_mode),
        .spi_start(spi_start),
        .execution_progress(execution_progress),
        .wait_active(wait_active),
        .wait_timeout_active(wait_timeout_active)
    );

    // SpaceGuard independent processor watchdog
    watchdog #(
        .HEARTBEAT_TIMEOUT(1000),
        .WAIT_TIMEOUT(100000)
    ) spaceguard_watchdog (
        .clk(clk),
        .rst_n(rst_n),
        .enable(!program_mode && !recovery_active),
        .heartbeat(execution_progress),
        .wait_active(wait_active),
        .wait_timeout_active(wait_timeout_active),
        .clear_fault(watchdog_clear),
        .fault(watchdog_fault)
    );

    // SpaceGuard automatic processor recovery controller
    recovery_controller #(
        .RESET_CYCLES(10),
        .RECOVERY_TIMEOUT(100),
        .MAX_ATTEMPTS(3)
    ) spaceguard_recovery (
        .clk(clk),
        .rst_n(rst_n),
        .critical_fault(critical_fault),
        .recovery_enable(!program_mode),
        .processor_heartbeat(execution_progress),
        .processor_reset_n(processor_reset_n),
        .recovery_active(recovery_active),
        .recovery_success(recovery_success),
        .recovery_failed(recovery_failed),
        .recovery_attempts(recovery_attempts)
    );

    // SpaceGuard Fault Manager
    fault_manager spaceguard_fault_manager (
        .clk(clk),
        .rst_n(rst_n),
        .fault_in(fault_inputs),
        .fault_enable(fault_enable),
        .clear_faults(fault_clear),
        .fault_status(fault_status),
        .fault_severity(fault_severity),
        .fault_irq(fault_irq),
        .fault_active(fault_active),
        .critical_fault(critical_fault)
    );

    // Processor timing generator
    timing_generator timer (
        .clk(clk),
        .rst_n(rst_n),
        .enable(1'b1),
        .divider({8'd0, timing_divider}),
        .tick(timing_tick)
    );

    // UART timing generator
    uart_timing_generator uart_timer (
        .clk(clk),
        .rst_n(rst_n),
        .enable(1'b1),
        .divider(uart_sample_divider),
        .sample_tick(uart_sample_tick),
        .baud_tick(uart_baud_tick)
    );

    // UART receiver: uio[0]
    uart_rx receiver (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uio_in[0]),
        .sample_tick(uart_sample_tick),
        .rx_data(uart_rx_data),
        .rx_valid(uart_rx_valid),
        .framing_error(uart_rx_framing_error),
        .rx_busy(uart_rx_busy)
    );

    // UART transmitter: uio[1]
    uart_tx transmitter (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(uart_baud_tick),
        .tx_start(uart_tx_start),
        .tx_data(uart_tx_data),
        .tx(uart_tx_line),
        .tx_busy(uart_tx_busy)
    );

    // SPI master
    spi_master spi (
        .clk(clk),
        .rst_n(rst_n),
        .start(spi_start),
        .tx_data(spi_tx_data),
        .divider(spi_divider),
        .spi_mode(spi_mode),
        .miso(uio_in[4]),
        .sclk(spi_sclk),
        .mosi(spi_mosi),
        .cs_n(spi_cs_n),
        .rx_data(spi_rx_data),
        .busy(spi_busy),
        .done(spi_done)
    );

    // GPIO output
    assign uo_out = gpio_out;

    // Pin allocation:
    // uio[0] = UART RX
    // uio[1] = UART TX
    // uio[2] = SPI SCLK
    // uio[3] = SPI MOSI
    // uio[4] = SPI MISO
    // uio[5] = SPI CS_N
    // uio[6] = SpaceGuard FAULT_IRQ
    // uio[7] = Reserved

    assign uio_out = {
        1'b0,
        fault_irq,
        spi_cs_n,
        1'b0,
        spi_mosi,
        spi_sclk,
        uart_tx_line,
        1'b0
    };

    // 1 = output, 0 = input
    assign uio_oe = 8'b01101110;

endmodule

`default_nettype wire
