
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
    input wire        timing_tick
);

    reg [3:0] pc;
    reg [15:0] program_mem [0:15];

    reg [15:0] instruction;
    reg [7:0] wait_counter;
    reg [7:0] gpio_in_prev;
    reg [7:0] shift_reg;
    // 8 x 8-bit configurable hardware register bank
    reg [7:0] config_regs [0:7];
    assign timing_divider = (config_regs[0] == 8'd1) ? config_regs[4] : (config_regs[0] == 8'd2) ? config_regs[5] : config_regs[3];
    integer reg_index;

// Register addresses
localparam REG_PERIPHERAL_SEL = 3'd0;
localparam REG_GPIO_DIR       = 3'd1;
localparam REG_GPIO_DATA      = 3'd2;
localparam REG_UART_DIV       = 3'd3;
localparam REG_SPI_DIV        = 3'd4;
localparam REG_I2C_DIV        = 3'd5;
localparam REG_STATUS         = 3'd6;
localparam REG_ERROR          = 3'd7;

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
    localparam OP_REG_WRITE    = 4'b1100;
    localparam OP_REG_READ     = 4'b1101;

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
    pc           <= 4'd0;
    instruction  <= 16'd0;
    gpio_out     <= 8'd0;
    wait_counter <= 8'd0;
    gpio_in_prev <= 8'd0;
    shift_reg    <= 8'd0;
    return_sp    <= 3'd0;

    // Reset all eight configuration registers
    for (reg_index = 0; reg_index < 8; reg_index = reg_index + 1) begin
        config_regs[reg_index] <= 8'd0;
    end

end else begin

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

                    // Write data into a configuration register
OP_REG_WRITE: begin
    if (program_mem[pc][11:8] < 8) begin
        config_regs[program_mem[pc][10:8]]
            <= program_mem[pc][7:0];
    end
end

// Read a configuration register
OP_REG_READ: begin
    if (program_mem[pc][11:8] < 8) begin
        gpio_out <= config_regs[program_mem[pc][10:8]];
    end
end

                    default: begin
                        gpio_out <= gpio_out;
                    end

                endcase

                instruction <= program_mem[pc];

                // Control-flow instructions manage their own PC.
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
        end
    end

endmodule

`default_nettype wire
