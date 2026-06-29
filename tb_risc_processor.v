`timescale 1s / 1s

module tb_risc_processor;

    reg clk1;
    reg clk2;
    reg rst;
    reg [31:0] din;
    wire [31:0] dout;
    wire halt;

    // Instantiate UUT
    risc_processor uut (
        .clk1(clk1),
        .clk2(clk2),
        .rst(rst),
        .din(din),
        .dout(dout),
        .halt(halt)
    );

    // Two-phase clock generation
    // clk1 and clk2 alternate every 10s cycle (20s period)
    initial begin
        clk1 = 0;
        clk2 = 0;
        forever begin
            #5 clk1 = 1;
            #5 clk1 = 0;
            #5 clk2 = 1;
            #5 clk2 = 0;
        end
    end

    integer i;

    initial begin
        $dumpfile("risc_sim.vcd");
        $dumpvars(0, tb_risc_processor);

        $display("=======================================================================================");
        $display("RUNNING DYNAMIC VERIFICATION (Instructions loaded from inst_data.mem)");
        $display("=======================================================================================");

        // Reset
        rst = 1;
        din = 32'b0;
        #17;
        rst = 0;

        $display("Time | IF_PC | IF_IR    | ID_IR    | EX_IR    | MEM_IR   | WB_IR    | R1 | R2 | R3 | R4 | Flags (CSZV) | Halt");
        $display("-------------------------------------------------------------------------------------------------------------");

        // Monitor loop for dynamic program execution
        while (!halt) begin
            @(posedge clk1);
            #3; // Let state settle
            $display("%4t |  %2d   | %8h | %8h | %8h | %8h | %8h | %2d | %2d | %2d | %2d |     %b     |  %b", 
                     $time, uut.PC_val, uut.IF_IR, uut.IF_ID_IR, uut.ID_EX_IR, uut.EX_MEM_IR, uut.MEM_WB_IR,
                     uut.decode_inst.rf[1], uut.decode_inst.rf[2], uut.decode_inst.rf[3], uut.decode_inst.rf[4], uut.flags, halt);
        end

        // Final state log
        @(posedge clk1);
        #3;
        $display("%4t |  %2d   | %8h | %8h | %8h | %8h | %8h | %2d | %2d | %2d | %2d |     %b     |  %b", 
                 $time, uut.PC_val, uut.IF_IR, uut.IF_ID_IR, uut.ID_EX_IR, uut.EX_MEM_IR, uut.MEM_WB_IR,
                 uut.decode_inst.rf[1], uut.decode_inst.rf[2], uut.decode_inst.rf[3], uut.decode_inst.rf[4], uut.flags, halt);

        $display("-------------------------------------------------------------------------------------------------------------");
        $display("Processor halted.");
        $display("========================================= REGISTER FILE =========================================");
        for (i = 0; i < 32; i = i + 1) begin
            if (uut.decode_inst.rf[i] !== 32'bx && uut.decode_inst.rf[i] !== 32'b0) begin
                $display("  R%0d = %d (0x%8h)", i, uut.decode_inst.rf[i], uut.decode_inst.rf[i]);
            end
        end
        $display("========================================= DATA MEMORY ==========================================");
        for (i = 0; i < 64; i = i + 1) begin
            if (uut.memory_inst.data_mem[i] !== 32'bx && uut.memory_inst.data_mem[i] !== 32'b0) begin
                $display("  MEM[%0d] = %d (0x%8h)", i, uut.memory_inst.data_mem[i], uut.memory_inst.data_mem[i]);
            end
        end
        $display("===============================================================================================");
        $finish;
    end

endmodule
