`timescale 1s / 1s

module hazard_unit (
    // Inputs from Decode
    input wire [4:0] IF_ID_rsrc1,
    input wire [4:0] IF_ID_rsrc2,
    input wire [4:0] IF_ID_rdes,
    input wire       IF_ID_imm_mode,
    input wire [4:0] IF_ID_opcode,
    
    // Inputs from Execute
    input wire [4:0] ID_EX_rsrc1,
    input wire [4:0] ID_EX_rsrc2,
    input wire [4:0] ID_EX_rdes,
    input wire       ID_EX_imm_mode,
    input wire [4:0] ID_EX_opcode,
    
    // Inputs from Memory / WB
    input wire [4:0] EX_MEM_rdes,
    input wire       EX_MEM_reg_write_en,
    
    input wire [4:0] MEM_WB_rdes,
    input wire       MEM_WB_reg_write_en,
    
    // Branch taken
    input wire branch_taken,
    
    // Outputs
    output reg stall_F,
    output reg stall_D,
    output reg flush_D,
    output reg flush_E,
    output reg [1:0] forward_A,
    output reg [1:0] forward_B,
    output reg [1:0] forward_rdes
);

    parameter OP_STOREREG = 5'd12;
    parameter OP_SENDDOUT = 5'd14;
    parameter OP_SENDREG  = 5'd15;

    // Forwarding Logic to EX Stage (clk1)
    always @(*) begin
        // Operand A Forwarding
        if (EX_MEM_reg_write_en && (EX_MEM_rdes != 5'b0) && (EX_MEM_rdes == ID_EX_rsrc1)) begin
            forward_A = 2'b10; // Forward from EX_MEM ALUResult
        end else if (MEM_WB_reg_write_en && (MEM_WB_rdes != 5'b0) && (MEM_WB_rdes == ID_EX_rsrc1)) begin
            forward_A = 2'b01; // Forward from MEM_WB RegWriteData
        end else begin
            forward_A = 2'b00; // No forwarding
        end

        // Operand B Forwarding
        if (!ID_EX_imm_mode && EX_MEM_reg_write_en && (EX_MEM_rdes != 5'b0) && (EX_MEM_rdes == ID_EX_rsrc2)) begin
            forward_B = 2'b10;
        end else if (!ID_EX_imm_mode && MEM_WB_reg_write_en && (MEM_WB_rdes != 5'b0) && (MEM_WB_rdes == ID_EX_rsrc2)) begin
            forward_B = 2'b01;
        end else begin
            forward_B = 2'b00;
        end

        // rdes value Forwarding (for storereg or senddout)
        if (EX_MEM_reg_write_en && (EX_MEM_rdes != 5'b0) && (EX_MEM_rdes == ID_EX_rdes)) begin
            forward_rdes = 2'b10;
        end else if (MEM_WB_reg_write_en && (MEM_WB_rdes != 5'b0) && (MEM_WB_rdes == ID_EX_rdes)) begin
            forward_rdes = 2'b01;
        end else begin
            forward_rdes = 2'b00;
        end
    end

    // Stalling Logic for Load-Use Hazard
    wire load_use_hazard;
    assign load_use_hazard = (ID_EX_opcode == OP_SENDREG) && (ID_EX_rdes != 5'b0) &&
        ((ID_EX_rdes == IF_ID_rsrc1) ||
         (!IF_ID_imm_mode && (ID_EX_rdes == IF_ID_rsrc2)) ||
         ((IF_ID_opcode == OP_STOREREG || IF_ID_opcode == OP_SENDDOUT) && (ID_EX_rdes == IF_ID_rdes)));

    always @(*) begin
        stall_F = 1'b0;
        stall_D = 1'b0;
        flush_D = 1'b0;
        flush_E = 1'b0;

        if (load_use_hazard) begin
            stall_F = 1'b1;
            stall_D = 1'b1;
            flush_E = 1'b1; // bubble
        end

        if (branch_taken) begin
            flush_D = 1'b1; // clear IF_ID to NOP
        end
    end

endmodule
