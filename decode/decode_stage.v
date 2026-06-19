`timescale 1s / 1s

module decode_stage (
    input wire clk1,
    input wire rst,
    input wire [4:0] rsrc1,
    input wire [4:0] rsrc2,
    input wire [4:0] rdes,
    input wire reg_write_en,
    input wire [4:0] rdes_in,
    input wire [31:0] reg_write_data,
    output wire [31:0] op1_val,
    output wire [31:0] op2_val,
    output wire [31:0] rdes_val
);

    reg [31:0] rf [0:31];

    // Register File Writes (on clk1 posedge)
    integer idx;
    always @(posedge clk1 or posedge rst) begin
        if (rst) begin
            for (idx = 0; idx < 32; idx = idx + 1) begin
                rf[idx] <= #2 32'b0;
            end
        end else if (reg_write_en && rdes_in != 5'b0) begin
            rf[rdes_in] <= #2 reg_write_data;
        end
    end

    // Register File Reads (combinational)
    assign op1_val  = rf[rsrc1];
    assign op2_val  = rf[rsrc2];
    assign rdes_val = rf[rdes];

endmodule
