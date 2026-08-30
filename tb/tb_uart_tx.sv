// tb_uart_tx.sv
// Self-checking testbench for uart_tx. Synchronizes on the falling edge
// of tx_serial (start of the start bit) and then samples every
// subsequent bit at its mid-point, exactly like a real UART receiver
// would. This makes the check independent of the DUT's internal
// state-machine latency.
`timescale 1ns/1ps

module tb_uart_tx;

    localparam int  CLK_FREQ_HZ    = 50_000_000;
    localparam int  BAUD_RATE      = 115_200;
    localparam int  CLKS_PER_BIT   = CLK_FREQ_HZ / BAUD_RATE;
    localparam real CLK_PERIOD_NS  = 1_000_000_000.0 / CLK_FREQ_HZ;
    localparam real BIT_PERIOD_NS  = CLK_PERIOD_NS * CLKS_PER_BIT;

    logic       clk = 0;
    logic       rst_n = 0;
    logic       tx_valid = 0;
    logic [7:0] tx_data = 8'h00;
    logic       tx_ready;
    logic       tx_serial;

    int errors = 0;

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_valid (tx_valid),
        .tx_data  (tx_data),
        .tx_ready (tx_ready),
        .tx_serial(tx_serial)
    );

    always #(CLK_PERIOD_NS / 2.0) clk = ~clk;

    initial begin
        $dumpfile("tb_uart_tx.vcd");
        $dumpvars(0, tb_uart_tx);
    end

    task automatic check(input logic actual, input logic expected, input string name);
        if (actual !== expected) begin
            $display("FAIL: %-10s = %b, expected %b at t=%0t", name, actual, expected, $time);
            errors++;
        end else begin
            $display("PASS: %-10s = %b at t=%0t", name, actual, $time);
        end
    endtask

    task automatic send_and_check(input logic [7:0] data);
        // Wait until the DUT is actually ready before driving a new byte
        wait (tx_ready === 1'b1);

        // Kick off a transmission
        @(posedge clk);
        tx_data  <= data;
        tx_valid <= 1'b1;
        @(posedge clk);
        tx_valid <= 1'b0;

        // Synchronize on the falling edge that marks the start bit,
        // regardless of how many cycles the FSM took to get there.
        @(negedge tx_serial);

        // Start bit: check at its mid-point
        #(BIT_PERIOD_NS * 0.5);
        check(tx_serial, 1'b0, "start bit");

        // 8 data bits, LSB first, each at its mid-point
        for (int i = 0; i < 8; i++) begin
            #(BIT_PERIOD_NS);
            check(tx_serial, data[i], $sformatf("data[%0d]", i));
        end

        // Stop bit
        #(BIT_PERIOD_NS);
        check(tx_serial, 1'b1, "stop bit");
    endtask

    initial begin
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        check(tx_serial, 1'b1, "idle line");

        send_and_check(8'hA5); // 1010_0101
        send_and_check(8'h00);
        send_and_check(8'hFF);

        $display("=====================================");
        if (errors == 0) begin
            $display("  ALL CHECKS PASSED");
            $display("=====================================");
            $finish;
        end else begin
            $display("  %0d CHECK(S) FAILED", errors);
            $display("=====================================");
            // $fatal (not $finish) so the simulator process exits non-zero
            // and a CI job actually fails when a check fails.
            $fatal(1, "%0d check(s) failed", errors);
        end
    end

endmodule
