`timescale 1ns/1ps

module serial_loader_tb;

    reg clk;
    reg rst_n;
    reg serial_in;
    reg serial_valid;

    wire load_en;
    wire [3:0] load_addr;
    wire [15:0] load_data;

    serial_loader dut (
        .clk(clk),
        .rst_n(rst_n),
        .serial_in(serial_in),
        .serial_valid(serial_valid),
        .load_en(load_en),
        .load_addr(load_addr),
        .load_data(load_data)
    );

    always #5 clk = ~clk;

    task send_bit;
        input bit_value;
        begin
            serial_in = bit_value;
            serial_valid = 1'b1;
            @(posedge clk);
            #1;
            serial_valid = 1'b0;
            @(posedge clk);
        end
    endtask

    integer i;

    reg [15:0] test_instruction;
    reg [15:0] test_instruction2;

    initial begin
        clk = 0;
        rst_n = 0;
        serial_in = 0;
        serial_valid = 0;

        test_instruction = 16'h1234;
        test_instruction2 = 16'hABCD;

        #20;
        rst_n = 1;

        // Send instruction MSB first
        for (i = 15; i >= 0; i = i - 1) begin
            send_bit(test_instruction[i]);
        end

        for (i = 15; i >= 0; i = i - 1) begin
            send_bit(test_instruction2[i]);
        end


if (load_data == test_instruction2 && load_addr == 4'd2)
    $display("SERIAL LOADER PASS");
else
    $display("SERIAL LOADER FAIL: data=%h address=%d",
             load_data, load_addr);


        #10;
        $finish;
    end

endmodule
