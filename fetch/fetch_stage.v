`timescale 1s / 1s

module fetch_stage (
    input wire clk1,
    input wire rst,
    input wire stall_F,
    input wire branch_taken,
    input wire [31:0] branch_target,
    output reg [31:0] PC,
    output wire [31:0] IR
);

    reg [31:0] inst_mem [0:63];

    // Instruction Memory Read (combinational)
    assign IR = inst_mem[PC[5:0]];

    // Next PC calculation
    wire [31:0] PC_next = branch_taken ? branch_target : (PC + 1);

    // PC register update on clk1 posedge
    always @(posedge clk1 or posedge rst) begin
        if (rst) begin
            PC <= #2 32'b0;
        end else if (!stall_F) begin
            PC <= #2 PC_next;
        end
    end

    // Load instruction memory
    integer idx;
    initial begin
        for (idx = 0; idx < 64; idx = idx + 1) begin
            inst_mem[idx] = 32'hd0000000; // default to NOP
        end
        $readmemh("inst_data.mem", inst_mem);
    end

endmodule
