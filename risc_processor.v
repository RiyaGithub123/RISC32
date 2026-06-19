`timescale 1s / 1s

module risc_processor (
    input wire clk1,
    input wire clk2,
    input wire rst,
    input wire [31:0] din,
    output reg [31:0] dout,
    output reg halt
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
    parameter OP_STOREDIN = 5'd13;
    parameter OP_SENDDOUT = 5'd14;
    parameter OP_SENDREG  = 5'd15;
    parameter OP_JUMP     = 5'd16;
    parameter OP_JC       = 5'd17;
    parameter OP_JNC      = 5'd18;
    parameter OP_JS       = 5'd19;
    parameter OP_JNS      = 5'd20;
    parameter OP_JZ       = 5'd21;
    parameter OP_JNZ      = 5'd22;
    parameter OP_JV       = 5'd23;
    parameter OP_JNV      = 5'd24;
    parameter OP_NOP      = 5'd26;
    parameter OP_HALT     = 5'd27;

    // Pipeline Registers
    // 1. IF/ID Registers (clk1)
    reg [31:0] IF_ID_IR;

    // 2. ID/EX Registers (clk2)
    reg [31:0] ID_EX_IR;
    reg [4:0]  ID_EX_opcode;
    reg [4:0]  ID_EX_rdes;
    reg [4:0]  ID_EX_rsrc1;
    reg [4:0]  ID_EX_rsrc2;
    reg        ID_EX_imm_mode;
    reg [31:0] ID_EX_op1;
    reg [31:0] ID_EX_op2;
    reg [31:0] ID_EX_rdes_val;

    // 3. EX/MEM Registers (clk1)
    reg [31:0] EX_MEM_IR;
    reg [4:0]  EX_MEM_opcode;
    reg [4:0]  EX_MEM_rdes;
    reg [31:0] EX_MEM_ALUOut;
    reg [31:0] EX_MEM_rdes_val;
    reg        EX_MEM_reg_write_en;

    // 4. MEM/WB Registers (clk2)
    reg [31:0] MEM_WB_IR;
    reg [4:0]  MEM_WB_opcode;
    reg [4:0]  MEM_WB_rdes;
    reg [31:0] MEM_WB_ALUOut;
    reg [31:0] MEM_WB_LMD;
    reg        MEM_WB_reg_write_en;

    // Core Registers
    reg [3:0] flags; // {Carry, Sign, Zero, Overflow}

    // Hazard Unit Outputs
    wire stall_F;
    wire stall_D;
    wire flush_D;
    wire flush_E;
    wire [1:0] forward_A;
    wire [1:0] forward_B;
    wire [1:0] forward_rdes;

    // -------------------------------------------------------------------------
    // IF Stage
    // -------------------------------------------------------------------------
    wire [31:0] PC_val;
    wire [31:0] IF_IR;
    
    // Branch Decision (computed in EX stage, but used in IF stage)
    wire branch_taken;
    wire [31:0] branch_target;

    fetch_stage fetch_inst (
        .clk1(clk1),
        .rst(rst),
        .stall_F(stall_F || halt),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .PC(PC_val),
        .IR(IF_IR)
    );

    // IF/ID Register update (clk1 posedge)
    always @(posedge clk1 or posedge rst) begin
        if (rst) begin
            IF_ID_IR <= #2 32'hd0000000; // NOP (opcode OP_NOP)
        end else if (flush_D) begin
            IF_ID_IR <= #2 32'hd0000000; // Flush with NOP
        end else if (!stall_D) begin
            IF_ID_IR <= #2 IF_IR;
        end
    end

    // -------------------------------------------------------------------------
    // ID Stage
    // -------------------------------------------------------------------------
    wire [4:0] ID_opcode   = IF_ID_IR[31:27];
    wire [4:0] ID_rdes     = IF_ID_IR[26:22];
    wire [4:0] ID_rsrc1    = IF_ID_IR[21:17];
    wire       ID_imm_mode = IF_ID_IR[16];
    wire [4:0] ID_rsrc2    = IF_ID_IR[15:11];
    wire [15:0] ID_imm     = IF_ID_IR[15:0];

    wire [31:0] ID_op1_val;
    wire [31:0] ID_op2_val;
    wire [31:0] ID_rdes_val;

    // RegWriteData calculation in WB stage
    reg [31:0] reg_write_data;
    always @(*) begin
        case (MEM_WB_opcode)
            OP_STOREDIN: reg_write_data = din;
            OP_SENDREG:  reg_write_data = MEM_WB_LMD;
            default:     reg_write_data = MEM_WB_ALUOut;
        endcase
    end

    decode_stage decode_inst (
        .clk1(clk1),
        .rst(rst),
        .rsrc1(ID_rsrc1),
        .rsrc2(ID_rsrc2),
        .rdes(ID_rdes),
        .reg_write_en(MEM_WB_reg_write_en),
        .rdes_in(MEM_WB_rdes),
        .reg_write_data(reg_write_data),
        .op1_val(ID_op1_val),
        .op2_val(ID_op2_val),
        .rdes_val(ID_rdes_val)
    );

    // ID/EX Register update (clk2 posedge)
    wire [31:0] ID_sign_ext_imm = {{16{ID_imm[15]}}, ID_imm};
    
    always @(posedge clk2 or posedge rst) begin
        if (rst) begin
            ID_EX_IR       <= #2 32'hd0000000;
            ID_EX_opcode   <= #2 5'd26; // NOP
            ID_EX_rdes     <= #2 5'd0;
            ID_EX_rsrc1    <= #2 5'd0;
            ID_EX_rsrc2    <= #2 5'd0;
            ID_EX_imm_mode <= #2 1'b0;
            ID_EX_op1      <= #2 32'b0;
            ID_EX_op2      <= #2 32'b0;
            ID_EX_rdes_val <= #2 32'b0;
        end else if (flush_E) begin
            ID_EX_IR       <= #2 32'hd0000000;
            ID_EX_opcode   <= #2 5'd26; // NOP
            ID_EX_rdes     <= #2 5'd0;
            ID_EX_rsrc1    <= #2 5'd0;
            ID_EX_rsrc2    <= #2 5'd0;
            ID_EX_imm_mode <= #2 1'b0;
            ID_EX_op1      <= #2 32'b0;
            ID_EX_op2      <= #2 32'b0;
            ID_EX_rdes_val <= #2 32'b0;
        end else begin
            ID_EX_IR       <= #2 IF_ID_IR;
            ID_EX_opcode   <= #2 ID_opcode;
            ID_EX_rdes     <= #2 ID_rdes;
            ID_EX_rsrc1    <= #2 ID_rsrc1;
            ID_EX_rsrc2    <= #2 ID_rsrc2;
            ID_EX_imm_mode <= #2 ID_imm_mode;
            ID_EX_op1      <= #2 ID_op1_val;
            ID_EX_op2      <= #2 ID_imm_mode ? ID_sign_ext_imm : ID_op2_val;
            ID_EX_rdes_val <= #2 ID_rdes_val;
        end
    end

    // -------------------------------------------------------------------------
    // EX Stage
    // -------------------------------------------------------------------------
    // Forwarding Muxes
    reg [31:0] EX_forwarded_op1;
    always @(*) begin
        case (forward_A)
            2'b10:   EX_forwarded_op1 = EX_MEM_ALUOut;
            2'b01:   EX_forwarded_op1 = reg_write_data;
            default: EX_forwarded_op1 = ID_EX_op1;
        endcase
    end

    reg [31:0] EX_forwarded_op2;
    always @(*) begin
        if (ID_EX_imm_mode) begin
            EX_forwarded_op2 = ID_EX_op2; // Immediate is never forwarded
        end else begin
            case (forward_B)
                2'b10:   EX_forwarded_op2 = EX_MEM_ALUOut;
                2'b01:   EX_forwarded_op2 = reg_write_data;
                default: EX_forwarded_op2 = ID_EX_op2;
            endcase
        end
    end

    reg [31:0] EX_forwarded_rdes_val;
    always @(*) begin
        case (forward_rdes)
            2'b10:   EX_forwarded_rdes_val = EX_MEM_ALUOut;
            2'b01:   EX_forwarded_rdes_val = reg_write_data;
            default: EX_forwarded_rdes_val = ID_EX_rdes_val;
        endcase
    end

    // ALU instantiation
    wire [31:0] EX_alu_out;
    wire [3:0]  EX_alu_flags;
    wire        EX_flags_en;

    execute_stage execute_inst (
        .opcode(ID_EX_opcode),
        .op1(EX_forwarded_op1),
        .op2(EX_forwarded_op2),
        .flags_in(flags),
        .alu_out(EX_alu_out),
        .alu_flags(EX_alu_flags),
        .flags_en(EX_flags_en)
    );

    // Branch Resolution Logic (in EX stage)
    reg EX_branch_taken;
    always @(*) begin
        case (ID_EX_opcode)
            OP_JUMP: EX_branch_taken = 1'b1;
            OP_JC:   EX_branch_taken = flags[3]; // Carry
            OP_JNC:  EX_branch_taken = ~flags[3];
            OP_JS:   EX_branch_taken = flags[2]; // Sign
            OP_JNS:  EX_branch_taken = ~flags[2];
            OP_JZ:   EX_branch_taken = flags[1]; // Zero
            OP_JNZ:  EX_branch_taken = ~flags[1];
            OP_JV:   EX_branch_taken = flags[0]; // Overflow
            OP_JNV:  EX_branch_taken = ~flags[0];
            default: EX_branch_taken = 1'b0;
        endcase
    end

    assign branch_taken = EX_branch_taken;
    assign branch_target = EX_forwarded_op2; // target PC is always forwarded operand 2 (register value or sign extended imm)

    // Register Write Enable calculation for EX stage to pass down
    wire EX_reg_write_en = (ID_EX_opcode == OP_MOV) || (ID_EX_opcode == OP_ADD) || (ID_EX_opcode == OP_SUB) ||
                           (ID_EX_opcode == OP_MUL) || (ID_EX_opcode == OP_MOVSGPR) ||
                           (ID_EX_opcode >= 5'd5 && ID_EX_opcode <= 5'd11) || // Logical rand to rnot
                           (ID_EX_opcode == OP_STOREDIN) || (ID_EX_opcode == OP_SENDREG);

    // EX/MEM Register update (clk1 posedge)
    always @(posedge clk1 or posedge rst) begin
        if (rst) begin
            EX_MEM_IR           <= #2 32'hd0000000;
            EX_MEM_opcode       <= #2 5'd26;
            EX_MEM_rdes         <= #2 5'd0;
            EX_MEM_ALUOut       <= #2 32'b0;
            EX_MEM_rdes_val     <= #2 32'b0;
            EX_MEM_reg_write_en <= #2 1'b0;
        end else begin
            EX_MEM_IR           <= #2 ID_EX_IR;
            EX_MEM_opcode       <= #2 ID_EX_opcode;
            EX_MEM_rdes         <= #2 ID_EX_rdes;
            // Write ALU output or flags (if movsgpr)
            if (ID_EX_opcode == OP_MOVSGPR) begin
                EX_MEM_ALUOut   <= #2 {28'b0, flags};
            end else begin
                EX_MEM_ALUOut   <= #2 EX_alu_out;
            end
            EX_MEM_rdes_val     <= #2 EX_forwarded_rdes_val;
            EX_MEM_reg_write_en <= #2 EX_reg_write_en;

            // Update status flags
            if (EX_flags_en) begin
                flags <= #2 EX_alu_flags;
            end
        end
    end

    // -------------------------------------------------------------------------
    // MEM Stage
    // -------------------------------------------------------------------------
    wire [31:0] MEM_read_data;
    wire MEM_write_en = (EX_MEM_opcode == OP_STOREREG);

    memory_stage memory_inst (
        .clk2(clk2),
        .rst(rst),
        .mem_write_en(MEM_write_en),
        .mem_addr(EX_MEM_ALUOut),
        .mem_write_data(EX_MEM_rdes_val),
        .mem_read_data(MEM_read_data)
    );

    // MEM/WB Register update (clk2 posedge)
    always @(posedge clk2 or posedge rst) begin
        if (rst) begin
            MEM_WB_IR           <= #2 32'hd0000000;
            MEM_WB_opcode       <= #2 5'd26;
            MEM_WB_rdes         <= #2 5'd0;
            MEM_WB_ALUOut       <= #2 32'b0;
            MEM_WB_LMD          <= #2 32'b0;
            MEM_WB_reg_write_en <= #2 1'b0;
        end else begin
            MEM_WB_IR           <= #2 EX_MEM_IR;
            MEM_WB_opcode       <= #2 EX_MEM_opcode;
            MEM_WB_rdes         <= #2 EX_MEM_rdes;
            MEM_WB_ALUOut       <= #2 EX_MEM_ALUOut;
            MEM_WB_LMD          <= #2 MEM_read_data;
            MEM_WB_reg_write_en <= #2 EX_MEM_reg_write_en;
        end
    end

    // -------------------------------------------------------------------------
    // WB Stage
    // -------------------------------------------------------------------------
    // The actual Register File write is done inside the decode stage on clk1,
    // which is connected to MEM_WB_reg_write_en, MEM_WB_rdes, and reg_write_data.
    
    // Halt and I/O logic in WB Stage
    always @(posedge clk1 or posedge rst) begin
        if (rst) begin
            halt <= #2 1'b0;
            dout <= #2 32'b0;
        end else begin
            if (MEM_WB_opcode == OP_HALT) begin
                halt <= #2 1'b1;
            end
            if (MEM_WB_opcode == OP_SENDDOUT) begin
                dout <= #2 reg_write_data;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Hazard Unit
    // -------------------------------------------------------------------------
    hazard_unit hazard_inst (
        .IF_ID_rsrc1(ID_rsrc1),
        .IF_ID_rsrc2(ID_rsrc2),
        .IF_ID_rdes(ID_rdes),
        .IF_ID_imm_mode(ID_imm_mode),
        .IF_ID_opcode(ID_opcode),
        .ID_EX_rsrc1(ID_EX_rsrc1),
        .ID_EX_rsrc2(ID_EX_rsrc2),
        .ID_EX_rdes(ID_EX_rdes),
        .ID_EX_imm_mode(ID_EX_imm_mode),
        .ID_EX_opcode(ID_EX_opcode),
        .EX_MEM_rdes(EX_MEM_rdes),
        .EX_MEM_reg_write_en(EX_MEM_reg_write_en),
        .MEM_WB_rdes(MEM_WB_rdes),
        .MEM_WB_reg_write_en(MEM_WB_reg_write_en),
        .branch_taken(branch_taken),
        .stall_F(stall_F),
        .stall_D(stall_D),
        .flush_D(flush_D),
        .flush_E(flush_E),
        .forward_A(forward_A),
        .forward_B(forward_B),
        .forward_rdes(forward_rdes)
    );

endmodule
