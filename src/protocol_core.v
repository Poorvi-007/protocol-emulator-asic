`default_nettype none

module protocol_core (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] gpio_in,
    output reg  [7:0] gpio_out,
    output wire [7:0] timing_divider,

    input wire        load_en,
    input wire [3:0]  load_addr,
    input wire [15:0] load_data,
    input wire        program_mode,
    input wire        timing_tick,

    // UART interface
    input  wire [7:0] uart_rx_data,
    input  wire       uart_rx_valid,
    input  wire       uart_rx_framing_error,
    input  wire       uart_rx_busy,
    input  wire       uart_tx_busy,
    output wire [7:0] uart_tx_data,
    output reg        uart_tx_start,
    output wire [15:0] uart_sample_divider,

    // SPI master interface
    input  wire [7:0] spi_rx_data,
    input  wire       spi_busy,
    input  wire       spi_done,
    output wire [7:0] spi_tx_data,
    output wire [7:0] spi_divider,
    output wire [1:0] spi_mode,
    output reg        spi_start,
    output reg        execution_progress,
    output wire       wait_active
);

    reg [3:0] pc;
    reg [3:0] pc_prev;
    reg [15:0] program_mem [0:15];

    reg [15:0] instruction;
    reg [7:0] wait_counter;
    reg [7:0] gpio_in_prev;
    reg [7:0] shift_reg;

    // Sixteen 8-bit configuration registers
    reg [7:0] config_regs [0:15];
    integer reg_index;

    // UART sticky status flags
    reg uart_rx_available;
    reg uart_frame_error_sticky;
    reg uart_tx_overrun;

    // SPI sticky status flags
    reg spi_done_sticky;
    reg spi_rx_available;
    reg spi_overrun;

    assign timing_divider =
        (config_regs[0] == 8'd1) ? config_regs[4] :
        (config_regs[0] == 8'd2) ? config_regs[5] :
        config_regs[3];

    assign uart_tx_data = config_regs[8];

    // SPI configuration outputs
    assign spi_tx_data = config_regs[13];
    assign spi_divider = config_regs[4];
    assign spi_mode = config_regs[15][2:1];

    // Register 3 = divider low byte
    // Register 12 = divider high byte
    assign uart_sample_divider = {
        config_regs[12], config_regs[3]
    };

    // Four-level return-address stack
    reg [3:0] return_stack [0:3];
    reg [2:0] return_sp;

    // Opcodes
    localparam OP_NOP          = 4'b0000;
    localparam OP_WRITE        = 4'b0001;
    localparam OP_READ         = 4'b0010;
    localparam OP_WAIT         = 4'b0011;
    localparam OP_WAIT_EDGE    = 4'b0100;
    localparam OP_JUMP         = 4'b0101;
    localparam OP_JUMP_IF_HIGH = 4'b0110;
    localparam OP_JUMP_IF_LOW  = 4'b0111;
    localparam OP_SHIFT_IN     = 4'b1000;
    localparam OP_SHIFT_OUT    = 4'b1001;
    localparam OP_CALL         = 4'b1010;
    localparam OP_RETURN       = 4'b1011;

    // SpaceGuard watchdog monitoring signals
    assign wait_active = !program_mode &&
        ((program_mem[pc][15:12] == OP_WAIT) ||
         (program_mem[pc][15:12] == OP_WAIT_EDGE));


    localparam OP_REG_WRITE    = 4'b1100;
    localparam OP_REG_READ     = 4'b1101;

    // Existing register addresses
    localparam REG_PERIPHERAL_SEL = 4'd0;
    localparam REG_GPIO_DIR       = 4'd1;
    localparam REG_GPIO_DATA      = 4'd2;
    localparam REG_UART_DIV_LO    = 4'd3;
    localparam REG_SPI_DIV        = 4'd4;
    localparam REG_I2C_DIV        = 4'd5;
    localparam REG_STATUS         = 4'd6;
    localparam REG_ERROR          = 4'd7;

    // UART register addresses
    localparam REG_UART_TX_DATA = 4'd8;
    localparam REG_UART_TX_CTRL = 4'd9;
    localparam REG_UART_RX_DATA = 4'd10;
    localparam REG_UART_STATUS  = 4'd11;
    localparam REG_UART_DIV_HI  = 4'd12;

    // SPI register addresses
    localparam REG_SPI_TX_DATA = 4'd13;
    localparam REG_SPI_RX_DATA = 4'd14;
    localparam REG_SPI_CTRL    = 4'd15;
    localparam REG_SPI_STATUS  = 4'd15;

    // Example program
    initial begin
        program_mem[0] = {OP_WRITE, 4'b0000, 8'b00000001};
        program_mem[1] = {OP_WRITE, 4'b0000, 8'b00000010};
        program_mem[2] = {OP_WRITE, 4'b0000, 8'b00000100};
        program_mem[3] = {OP_READ, 4'b0000, 8'b0};

        program_mem[4]  = 16'b0;
        program_mem[5]  = 16'b0;
        program_mem[6]  = 16'b0;
        program_mem[7]  = 16'b0;
        program_mem[8]  = 16'b0;
        program_mem[9]  = 16'b0;
        program_mem[10] = 16'b0;
        program_mem[11] = 16'b0;
        program_mem[12] = 16'b0;
        program_mem[13] = 16'b0;
        program_mem[14] = 16'b0;
        program_mem[15] = 16'b0;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            pc                     <= 4'd0;
            pc_prev                <= 4'd0;
            execution_progress     <= 1'b0;
            instruction            <= 16'd0;
            gpio_out               <= 8'd0;
            wait_counter           <= 8'd0;
            gpio_in_prev           <= 8'd0;
            shift_reg              <= 8'd0;
            return_sp              <= 3'd0;

            uart_tx_start          <= 1'b0;
            uart_rx_available      <= 1'b0;
            uart_frame_error_sticky <= 1'b0;
            uart_tx_overrun        <= 1'b0;
            spi_start              <= 1'b0;
            spi_done_sticky        <= 1'b0;
            spi_rx_available       <= 1'b0;
            spi_overrun            <= 1'b0;

            for (reg_index = 0; reg_index < 16;
                 reg_index = reg_index + 1) begin
                config_regs[reg_index] <= 8'd0;
            end

        end else begin

            // SpaceGuard: one-clock heartbeat on actual PC progress.
            execution_progress <= 1'b0;

            if (program_mode) begin
                pc_prev <= pc;
            end else begin
                if (pc != pc_prev)
                    execution_progress <= 1'b1;

                pc_prev <= pc;
            end

            // Default: UART start is a one-clock pulse
            uart_tx_start <= 1'b0;
            spi_start <= 1'b0;

            gpio_in_prev <= gpio_in;

            if (load_en) begin
                program_mem[load_addr] <= load_data;
            end

            if (!program_mode) begin

                case (program_mem[pc][15:12])

                    OP_NOP: begin
                        gpio_out <= gpio_out;
                    end

                    OP_WRITE: begin
                        gpio_out <= program_mem[pc][7:0];
                    end

                    OP_READ: begin
                        gpio_out <= gpio_in;
                    end

                    OP_WAIT: begin
                        if (wait_counter == 0) begin
                            wait_counter <= program_mem[pc][7:0];
                        end else if (timing_tick) begin
                            if (wait_counter == 1) begin
                                wait_counter <= 8'd0;
                                pc <= pc + 1'b1;
                            end else begin
                                wait_counter <= wait_counter - 1'b1;
                            end
                        end
                    end

                    OP_WAIT_EDGE: begin
                        if (gpio_in != gpio_in_prev) begin
                            pc <= pc + 1'b1;
                        end
                    end

                    OP_JUMP: begin
                        pc <= program_mem[pc][3:0];
                    end

                    OP_JUMP_IF_HIGH: begin
                        if (gpio_in[program_mem[pc][11:8]]) begin
                            pc <= program_mem[pc][3:0];
                        end else begin
                            pc <= pc + 1'b1;
                        end
                    end

                    OP_JUMP_IF_LOW: begin
                        if (!gpio_in[program_mem[pc][11:8]]) begin
                            pc <= program_mem[pc][3:0];
                        end else begin
                            pc <= pc + 1'b1;
                        end
                    end

                    OP_SHIFT_IN: begin
                        shift_reg <= {
                            shift_reg[6:0],
                            gpio_in[program_mem[pc][11:8]]
                        };

                        gpio_out <= {
                            shift_reg[6:0],
                            gpio_in[program_mem[pc][11:8]]
                        };
                    end

                    OP_SHIFT_OUT: begin
                        gpio_out <= shift_reg;
                    end

                    OP_CALL: begin
                        if (return_sp < 3'd4) begin
                            return_stack[return_sp] <= pc + 1'b1;
                            return_sp <= return_sp + 1'b1;
                            pc <= program_mem[pc][3:0];
                        end else begin
                            pc <= pc + 1'b1;
                        end
                    end

                    OP_RETURN: begin
                        if (return_sp != 0) begin
                            return_sp <= return_sp - 1'b1;
                            pc <= return_stack[return_sp - 1'b1];
                        end else begin
                            pc <= pc + 1'b1;
                        end
                    end

                    // Write configuration registers
                    OP_REG_WRITE: begin
                        case (program_mem[pc][11:8])

                            REG_SPI_CTRL: begin
                                config_regs[REG_SPI_CTRL] <= {5'b00000, program_mem[pc][2:1], 1'b0};
                                if (program_mem[pc][3])
                                    spi_done_sticky <= 1'b0;
                                if (program_mem[pc][4])
                                    spi_overrun <= 1'b0;
                                if (program_mem[pc][0]) begin
                                    if (!spi_busy)
                                        spi_start <= 1'b1;
                                    else
                                        spi_overrun <= 1'b1;
                                end
                            end

                            REG_UART_TX_CTRL: begin
                                if (program_mem[pc][0]) begin
                                    if (!uart_tx_busy) begin
                                        uart_tx_start <= 1'b1;
                                    end else begin
                                        uart_tx_overrun <= 1'b1;
                                    end
                                end
                            end


                            REG_UART_STATUS: begin
                                // Write-one-to-clear sticky flags
                                if (program_mem[pc][4])
                                    uart_tx_overrun <= 1'b0;

                                if (program_mem[pc][2])
                                    uart_frame_error_sticky <= 1'b0;
                            end

                            default: begin
                                config_regs[program_mem[pc][11:8]]
                                    <= program_mem[pc][7:0];
                            end

                        endcase
                    end

                    // Read configuration registers
                    OP_REG_READ: begin
                        case (program_mem[pc][11:8])

                            REG_SPI_STATUS: begin
                                gpio_out <= {4'b0000, spi_overrun, spi_rx_available, spi_done_sticky, spi_busy};
                            end

                            REG_UART_STATUS: begin
                                gpio_out <= {
                                    3'b000,
                                    uart_tx_overrun,
                                    uart_rx_busy,
                                    uart_frame_error_sticky,
                                    uart_rx_available,
                                    uart_tx_busy
                                };
                            end

                            default: begin
                                gpio_out <=
                                    config_regs[program_mem[pc][11:8]];
                            end

                        endcase

                        if (program_mem[pc][11:8] == REG_UART_RX_DATA)
                            uart_rx_available <= 1'b0;

                        if (program_mem[pc][11:8] == REG_SPI_RX_DATA)
                            spi_rx_available <= 1'b0;
                    end

                    default: begin
                        gpio_out <= gpio_out;
                    end

                endcase

                instruction <= program_mem[pc];

                // Control-flow instructions manage their own PC
                if ((program_mem[pc][15:12] != OP_WAIT) &&
                    (program_mem[pc][15:12] != OP_WAIT_EDGE) &&
                    (program_mem[pc][15:12] != OP_JUMP) &&
                    (program_mem[pc][15:12] != OP_JUMP_IF_HIGH) &&
                    (program_mem[pc][15:12] != OP_JUMP_IF_LOW) &&
                    (program_mem[pc][15:12] != OP_CALL) &&
                    (program_mem[pc][15:12] != OP_RETURN)) begin
                    pc <= pc + 1'b1;
                end
            end

            // Capture received UART bytes independently of program execution
            // This also ensures a new byte wins over a simultaneous RX read.
            // Capture completed SPI transfer
            if (spi_done) begin
                config_regs[REG_SPI_RX_DATA] <= spi_rx_data;
                spi_done_sticky <= 1'b1;
                spi_rx_available <= 1'b1;
            end

            if (uart_rx_valid) begin
                config_regs[REG_UART_RX_DATA] <= uart_rx_data;
                uart_rx_available <= 1'b1;

                if (uart_rx_framing_error) begin
                    uart_frame_error_sticky <= 1'b1;
                end
            end

        end
    end

endmodule

`default_nettype wire
