`timescale 1s / 1s

module execute_stage (
    input wire [4:0] opcode,
    input wire [31:0] op1,
    input wire [31:0] op2,
    input wire [3:0] flags_in,
    output reg [31:0] alu_out,
    output reg [3:0] alu_flags,
    output reg flags_en
);

    // Opcodes Definition
    parameter OP_MOV      = 5'd0;
    parameter OP_ADD      = 5'd1;
    parameter OP_SUB      = 5'd2;
    parameter OP_MUL      = 5'd3;
    parameter OP_MOVSGPR  = 5'd4;
    parameter OP_RAND     = 5'd5;
    parameter OP_ROR      = 5'd6;
    parameter OP_RXOR     = 5'd7;
    parameter OP_RXNOR    = 5'd8;
    parameter OP_RNAND    = 5'd9;
    parameter OP_RNOR     = 5'd10;
    parameter OP_RNOT     = 5'd11;
    parameter OP_STOREREG = 5'd12;
    parameter OP_SENDREG  = 5'd15;

    // Carry and Overflow helpers for Addition
    wire [32:0] add_res = {1'b0, op1} + {1'b0, op2};
    wire add_carry = add_res[32];
    wire add_overflow = (op1[31] == op2[31]) && (add_res[31] != op1[31]);

    // Carry (borrow) and Overflow helpers for Subtraction
    wire [32:0] sub_res = {1'b0, op1} - {1'b0, op2};
    wire sub_borrow = op1 < op2;
    wire sub_overflow = (op1[31] != op2[31]) && (sub_res[31] != op1[31]);

    always @(*) begin
        alu_out = 32'b0;
        alu_flags = 4'b0;
        flags_en = 1'b0;
        case (opcode)
            OP_MOV: begin
                alu_out = op2;
                alu_flags[3] = flags_in[3]; // Carry unchanged
                alu_flags[2] = alu_out[31]; // Sign
                alu_flags[1] = (alu_out == 32'b0); // Zero
                alu_flags[0] = flags_in[0]; // Overflow unchanged
                flags_en = 1'b1;
            end
            OP_ADD: begin
                alu_out = add_res[31:0];
                alu_flags[3] = add_carry;
                alu_flags[2] = alu_out[31];
                alu_flags[1] = (alu_out == 32'b0);
                alu_flags[0] = add_overflow;
                flags_en = 1'b1;
            end
            OP_SUB: begin
                alu_out = sub_res[31:0];
                alu_flags[3] = sub_borrow;
                alu_flags[2] = alu_out[31];
                alu_flags[1] = (alu_out == 32'b0);
                alu_flags[0] = sub_overflow;
                flags_en = 1'b1;
            end
            OP_MUL: begin
                alu_out = op1 * op2;
                alu_flags[3] = 1'b0;
                alu_flags[2] = alu_out[31];
                alu_flags[1] = (alu_out == 32'b0);
                alu_flags[0] = 1'b0;
                flags_en = 1'b1;
            end
            OP_RAND: begin
                alu_out = op1 & op2;
                alu_flags[3] = 1'b0;
                alu_flags[2] = alu_out[31];
                alu_flags[1] = (alu_out == 32'b0);
                alu_flags[0] = 1'b0;
                flags_en = 1'b1;
            end
            OP_ROR: begin
                alu_out = op1 | op2;
                alu_flags[3] = 1'b0;
                alu_flags[2] = alu_out[31];
                alu_flags[1] = (alu_out == 32'b0);
                alu_flags[0] = 1'b0;
                flags_en = 1'b1;
            end
            OP_RXOR: begin
                alu_out = op1 ^ op2;
                alu_flags[3] = 1'b0;
                alu_flags[2] = alu_out[31];
                alu_flags[1] = (alu_out == 32'b0);
                alu_flags[0] = 1'b0;
                flags_en = 1'b1;
            end
            OP_RXNOR: begin
                alu_out = ~(op1 ^ op2);
                alu_flags[3] = 1'b0;
                alu_flags[2] = alu_out[31];
                alu_flags[1] = (alu_out == 32'b0);
                alu_flags[0] = 1'b0;
                flags_en = 1'b1;
            end
            OP_RNAND: begin
                alu_out = ~(op1 & op2);
                alu_flags[3] = 1'b0;
                alu_flags[2] = alu_out[31];
                alu_flags[1] = (alu_out == 32'b0);
                alu_flags[0] = 1'b0;
                flags_en = 1'b1;
            end
            OP_RNOR: begin
                alu_out = ~(op1 | op2);
                alu_flags[3] = 1'b0;
                alu_flags[2] = alu_out[31];
                alu_flags[1] = (alu_out == 32'b0);
                alu_flags[0] = 1'b0;
                flags_en = 1'b1;
            end
            OP_RNOT: begin
                alu_out = ~op1;
                alu_flags[3] = 1'b0;
                alu_flags[2] = alu_out[31];
                alu_flags[1] = (alu_out == 32'b0);
                alu_flags[0] = 1'b0;
                flags_en = 1'b1;
            end
            OP_STOREREG, OP_SENDREG: begin
                alu_out = op1 + op2;
                alu_flags = flags_in;
                flags_en = 1'b0;
            end
            default: begin
                alu_out = 32'b0;
                alu_flags = 4'b0;
                flags_en = 1'b0;
            end
        endcase
    end

endmodule
