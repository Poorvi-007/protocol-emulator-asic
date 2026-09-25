/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`include "protocol_core.v"
`include "serial_loader.v"
module tt_um_protocol_emulator (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
wire [7:0] gpio_out;

wire        load_en;
wire [3:0]  load_addr;
wire [15:0] load_data;
wire        program_mode;
assign program_mode = ui_in[2];
serial_loader loader (
    .clk(clk),
    .rst_n(rst_n),
    .serial_in(ui_in[0]),
    .serial_valid(ui_in[1]),
    .load_en(load_en),
    .load_addr(load_addr),
    .load_data(load_data)
);


protocol_core core (
    .clk(clk),
    .rst_n(rst_n),
    .gpio_in(ui_in),
    .gpio_out(gpio_out),
    .load_en(load_en),
    .load_addr(load_addr),
    .load_data(load_data),
    .program_mode(program_mode)
);
  assign uo_out  = gpio_out;
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  // List all unused inputs to prevent warnings

endmodule
