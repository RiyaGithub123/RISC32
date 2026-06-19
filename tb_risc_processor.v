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

        // =====================================================================
        // PROGRAM 1: Simple Addition of 3 and 4
        // =====================================================================
        $display("==================================================================================================================================================");
        $display("RUNNING PROGRAM 1: Addition of 3 and 4 (Result expected in r3)");
        $display("==================================================================================================================================================");
        
        // Initialize instruction memory with NOPs
        for (i = 0; i < 64; i = i + 1) begin
            uut.fetch_inst.inst_mem[i] = 32'hd0000000;
        end
        
        // Load Program 1
        uut.fetch_inst.inst_mem[0] = 32'h00410003; // mov r1, #3
        uut.fetch_inst.inst_mem[1] = 32'h00810004; // mov r2, #4
        uut.fetch_inst.inst_mem[2] = 32'h08c21000; // add r3, r1, r2
        uut.fetch_inst.inst_mem[3] = 32'hd8010000; // halt

        // Reset
        rst = 1;
        din = 32'b0;
        #17;
        rst = 0;

        $display("Time | IF_PC | IF_IR    | ID_IR    | EX_IR    | MEM_IR   | WB_IR    | R1 | R2 | R3 (Result) | Flags (CSZV) | Halt");
        $display("--------------------------------------------------------------------------------------------------------------------------------------------------");

        // Monitor loop for Program 1
        while (!halt) begin
            @(posedge clk1);
            #3; // Let state settle
            $display("%4t |  %2d   | %8h | %8h | %8h | %8h | %8h | %2d | %2d | %11d |     %b     |  %b", 
                     $time, uut.PC_val, uut.IF_IR, uut.IF_ID_IR, uut.ID_EX_IR, uut.EX_MEM_IR, uut.MEM_WB_IR,
                     uut.decode_inst.rf[1], uut.decode_inst.rf[2], uut.decode_inst.rf[3], uut.flags, halt);
        end

        // Final state log
        @(posedge clk1);
        #3;
        $display("%4t |  %2d   | %8h | %8h | %8h | %8h | %8h | %2d | %2d | %11d |     %b     |  %b", 
                 $time, uut.PC_val, uut.IF_IR, uut.IF_ID_IR, uut.ID_EX_IR, uut.EX_MEM_IR, uut.MEM_WB_IR,
                 uut.decode_inst.rf[1], uut.decode_inst.rf[2], uut.decode_inst.rf[3], uut.flags, halt);

        $display("--------------------------------------------------------------------------------------------------------------------------------------------------");
        if (uut.decode_inst.rf[3] == 7) begin
            $display("SUCCESS: rf[3] matches 3 + 4 = 7!");
        end else begin
            $display("FAILURE: Expected rf[3] = 7, got %d", uut.decode_inst.rf[3]);
        end
        $display("==================================================================================================================================================\n");

        #20; // Wait a few cycles

        // =====================================================================
        // PROGRAM 2: Factorial of 5
        // =====================================================================
        $display("==================================================================================================================================================");
        $display("RUNNING PROGRAM 2: Factorial of 5 (Result expected in r4)");
        $display("==================================================================================================================================================");

        // Clear instruction memory with NOPs
        for (i = 0; i < 64; i = i + 1) begin
            uut.fetch_inst.inst_mem[i] = 32'hd0000000;
        end

        // Load Program 2
        uut.fetch_inst.inst_mem[0] = 32'h00810001; // mov r2, #1 (product)
        uut.fetch_inst.inst_mem[1] = 32'h00410005; // mov r1, #5 (counter)
        uut.fetch_inst.inst_mem[2] = 32'h18840800; // mul r2, r2, r1
        uut.fetch_inst.inst_mem[3] = 32'h10430001; // sub r1, r1, #1
        uut.fetch_inst.inst_mem[4] = 32'hb0010002; // jnz to 2
        uut.fetch_inst.inst_mem[5] = 32'h6081000f; // storereg r2, address 15
        uut.fetch_inst.inst_mem[6] = 32'h7901000f; // sendreg r4, address 15
        uut.fetch_inst.inst_mem[7] = 32'hd8010000; // halt

        // Reset
        rst = 1;
        #17;
        rst = 0;

        $display("Time | IF_PC | IF_IR    | ID_IR    | EX_IR    | MEM_IR   | WB_IR    | R1 | R2 (Accum) | R3 | R4 (Result) | Flags (CSZV) | Halt");
        $display("--------------------------------------------------------------------------------------------------------------------------------------------------");

        // Monitor loop for Program 2
        while (!halt) begin
            @(posedge clk1);
            #3; // Let state settle
            $display("%4t |  %2d   | %8h | %8h | %8h | %8h | %8h | %2d | %10d | %2d | %10d  |     %b     |  %b", 
                     $time, uut.PC_val, uut.IF_IR, uut.IF_ID_IR, uut.ID_EX_IR, uut.EX_MEM_IR, uut.MEM_WB_IR,
                     uut.decode_inst.rf[1], uut.decode_inst.rf[2], uut.decode_inst.rf[3], uut.decode_inst.rf[4], uut.flags, halt);
        end

        // Final state log
        @(posedge clk1);
        #3;
        $display("%4t |  %2d   | %8h | %8h | %8h | %8h | %8h | %2d | %10d | %2d | %10d  |     %b     |  %b", 
                 $time, uut.PC_val, uut.IF_IR, uut.IF_ID_IR, uut.ID_EX_IR, uut.EX_MEM_IR, uut.MEM_WB_IR,
                 uut.decode_inst.rf[1], uut.decode_inst.rf[2], uut.decode_inst.rf[3], uut.decode_inst.rf[4], uut.flags, halt);

        $display("--------------------------------------------------------------------------------------------------------------------------------------------------");
        if (uut.decode_inst.rf[4] == 120 && uut.memory_inst.data_mem[15] == 120) begin
            $display("SUCCESS: rf[4] matches 5! = 120, and memory[15] is indeed 120!");
        end else begin
            $display("FAILURE: Expected rf[4] = 120 and memory[15] = 120, got rf[4] = %d, memory[15] = %d, memory[0] = %d",
                     uut.decode_inst.rf[4], uut.memory_inst.data_mem[15], uut.memory_inst.data_mem[0]);
        end
        $display("==================================================================================================================================================");

        $finish;
    end

endmodule
