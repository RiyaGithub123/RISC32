`timescale 1s / 1s

module memory_stage (
    input wire clk2,
    input wire rst,
    input wire mem_write_en,
    input wire [31:0] mem_addr,
    input wire [31:0] mem_write_data,
    output wire [31:0] mem_read_data
);

    reg [31:0] data_mem [0:63];

    // Data Memory Writes (on clk2 posedge)
    always @(posedge clk2) begin
        if (!rst && mem_write_en) begin
            data_mem[mem_addr[5:0]] <= #2 mem_write_data;
        end
    end

    // Data Memory Reads (combinational)
    assign mem_read_data = data_mem[mem_addr[5:0]];

    // Initialize data memory
    integer idx;
    initial begin
        for (idx = 0; idx < 64; idx = idx + 1) begin
            data_mem[idx] = 32'h00000000;
        end
    end

endmodule
