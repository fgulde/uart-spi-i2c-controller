// uart_tx.sv
// Simple UART transmitter: 8 data bits, no parity, 1 stop bit (8N1).
module uart_tx #(
    parameter int CLK_FREQ_HZ = 50_000_000,
    parameter int BAUD_RATE   = 115_200
) (
    input  logic       clk,
    input  logic       rst_n,      // active-low synchronous reset

    input  logic        tx_valid,  // pulse high for 1 cycle to start a transmission
    input  logic [7:0]  tx_data,
    output logic        tx_ready,  // high when a new byte can be accepted

    output logic tx_serial          // idles high
);

    localparam int CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

    typedef enum logic [1:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT
    } state_e;

    state_e state;
    int unsigned              clk_count;
    logic [2:0]                bit_index;
    logic [7:0]                data_reg;

    assign tx_ready = (state == IDLE);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state     <= IDLE;
            clk_count <= '0;
            bit_index <= '0;
            tx_serial <= 1'b1;
            data_reg  <= '0;
        end else begin
            case (state)
                IDLE: begin
                    tx_serial <= 1'b1;
                    if (tx_valid) begin
                        data_reg  <= tx_data;
                        state     <= START_BIT;
                        clk_count <= '0;
                    end
                end

                START_BIT: begin
                    tx_serial <= 1'b0;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= '0;
                        bit_index <= '0;
                        state     <= DATA_BITS;
                    end
                end

                DATA_BITS: begin
                    tx_serial <= data_reg[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= '0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 3'd1;
                        end else begin
                            state <= STOP_BIT;
                        end
                    end
                end

                STOP_BIT: begin
                    tx_serial <= 1'b1;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= '0;
                        state     <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
