# Local Simulation and GTKWave Waveform Guide

This guide explains how to compile the pipelined RISC-V processor, run dynamic simulations locally, view the cycle-by-cycle trace in the terminal, and visualize signal timings/pipelining behavior using **GTKWave**.

---

## 🛠️ Prerequisites

To run simulations locally, you need the **OSS CAD Suite** which contains:
- **Icarus Verilog** (`iverilog`): Compilation tool for Verilog.
- **vvp**: Simulation runtime engine for compiled Verilog output.
- **GTKWave**: Graphical waveform viewer.

The environment setup batch file is located at `C:\oss-cad-suite\oss-cad-suite\environment.bat`.

---

## 🚀 Step 1: Run the Simulation

You can run the simulation using the automated batch script or manually step-by-step.

### Option A: Using the Automated Batch Script (Recommended)
Run the script [run_verification.bat](file:///c:/Users/bisha/OneDrive/Desktop/RISC-V/run_verification.bat) with the program name as an argument (`add` or `factorial`):

```cmd
# Run simulation for addition (default)
.\run_verification.bat add

# Run simulation for factorial
.\run_verification.bat factorial
```

### Option B: Running Manually
If you want to run the steps manually, run the following commands in your terminal:

1. **Activate the environment:**
   ```cmd
   call "C:\oss-cad-suite\oss-cad-suite\environment.bat"
   ```
2. **Translate the Assembly program to machine code:**
   ```cmd
   python riscv_translate.py add.s inst_data.mem
   ```
3. **Compile the design and testbench:**
   ```cmd
   iverilog -o risc_sim.vvp fetch/fetch_stage.v decode/decode_stage.v execute/execute_stage.v memory/memory_stage.v hazard/hazard_unit.v risc_processor.v tb_risc_processor.v
   ```
4. **Run the compiled simulation:**
   ```cmd
   vvp risc_sim.vvp
   ```

---

## 🖥️ Step 2: Understand the Terminal Output

When the simulation runs, it prints a cycle-by-cycle pipeline execution trace showing how instructions flow through the processor stages.

### Example Output (`add` program):
```text
VCD info: dumpfile risc_sim.vcd opened for output.
=======================================================================================
RUNNING DYNAMIC VERIFICATION (Instructions loaded from inst_data.mem)
=======================================================================================
Time | IF_PC | IF_IR    | ID_IR    | EX_IR    | MEM_IR   | WB_IR    | R1 | R2 | R3 | R4 | Flags (CSZV) | Halt
-------------------------------------------------------------------------------------------------------------
  28 |   1   | 00810004 | 00410003 | d0000000 | d0000000 | d0000000 |  0 |  0 |  0 |  0 |     xxxx     |  0
  48 |   2   | 08c21000 | 00810004 | 00410003 | 00410003 | d0000000 |  0 |  0 |  0 |  0 |     x00x     |  0
  68 |   3   | d8000000 | 08c21000 | 00810004 | 00810004 | 00410003 |  3 |  0 |  0 |  0 |     x00x     |  0
  88 |   4   | d0000000 | d8000000 | 08c21000 | 08c21000 | 00810004 |  3 |  4 |  0 |  0 |     0000     |  0
 108 |   5   | d0000000 | d0000000 | d8000000 | d8000000 | 08c21000 |  3 |  4 |  7 |  0 |     0000     |  0
 128 |   6   | d0000000 | d0000000 | d0000000 | d0000000 | d8000000 |  3 |  4 |  7 |  0 |     0000     |  1
 148 |   6   | d0000000 | d0000000 | d0000000 | d0000000 | d0000000 |  3 |  4 |  7 |  0 |     0000     |  1
-------------------------------------------------------------------------------------------------------------
Processor halted.
========================================= REGISTER FILE =========================================
  R1 =          3 (0x00000003)
  R2 =          4 (0x00000004)
  R3 =          7 (0x00000007)
========================================= DATA MEMORY ==========================================
===============================================================================================
```

### Key Columns in the Trace:
- **`Time`**: Simulation time step in seconds (clock period is 20s, consisting of two 10s phases).
- **`IF_PC`**: Program Counter in the Instruction Fetch stage.
- **`IF_IR`**: Fetched instruction word.
- **`ID_IR`**, **`EX_IR`**, **`MEM_IR`**, **`WB_IR`**: The instruction words residing in the Decode, Execute, Memory, and Writeback pipeline registers respectively.
  - Notice the **staircase pattern**! For example, `00410003` (`li x1, 3`) is in:
    - `ID_IR` at time 28
    - `EX_IR` and `MEM_IR` at time 48
    - `WB_IR` at time 68 (register `R1` updates to `3` right after this stage).
- **`R1` to `R4`**: Current decimal values of registers 1 through 4.
- **`Flags (CSZV)`**: ALU flags (Carry, Sign, Zero, oVerflow).
- **`Halt`**: Goes high (`1`) when the `HALT` instruction (hex `d8000000`) completes.

---

## 📈 Step 3: View Waveforms in GTKWave

The simulation writes all signal changes to a VCD (Value Change Dump) file named `risc_sim.vcd` (defined in [tb_risc_processor.v](file:///c:/Users/bisha/OneDrive/Desktop/RISC-V/tb_risc_processor.v#L38-L39)).

### 1. Launch GTKWave
Open GTKWave and load the VCD file by running this command in your terminal:
```cmd
gtkwave risc_sim.vcd
```

### 2. Add Signals to the Wave Window
When GTKWave opens:
1. In the upper-left **SST** (Sub-module Search Tree) panel, expand `tb_risc_processor` and select `uut` (the processor instance).
2. The bottom-left **Signals** panel will list all signals in the selected module.
3. Select the signals you want to trace and click **Append** at the bottom (or double-click the signals) to add them to the wave window.

### 🌟 Recommended Signals to Add:
For a clear view of the pipeline flow, add these signals in order:
- `clk1` and `clk2` (Two-phase clocks)
- `rst` (Reset signal)
- `PC_val` (Program Counter value)
- `IF_ID_IR` (Instruction word in Decode stage)
- `ID_EX_IR` (Instruction word in Execute stage)
- `EX_MEM_IR` (Instruction word in Memory stage)
- `MEM_WB_IR` (Instruction word in Writeback stage)

### 3. Change Data Format to Hexadecimal
By default, GTKWave shows large signal values (like instructions) in binary. To make them readable:
1. Select the instruction registers (`IF_ID_IR`, `ID_EX_IR`, etc.) in the wave window (hold `Ctrl` or `Shift` to select multiple).
2. Right-click the selected signals.
3. Choose **Data Format** -> **Hexadecimal** (or **Decimal** for registers/PC).

### 4. Adjust the View
- **Zoom Fit**: Press the **`f`** key (or click the magnifying glass with a box around it in the toolbar) to fit the entire simulation timescale on the screen.
- **Zoom In/Out**: Use `Ctrl` + scroll wheel, or click the `+` / `-` magnifying glass icons.

---

## 🔬 Verifying Pipelining and Hazards in GTKWave

### 1. Pipelining Staircase
Look at the values of `IF_ID_IR`, `ID_EX_IR`, `EX_MEM_IR`, and `MEM_WB_IR`. You will observe a diagonal/staircase alignment of the hex values as each instruction steps through the stages:
```text
           Cycle 1     Cycle 2     Cycle 3     Cycle 4
IF_ID_IR  [Inst A]    [Inst B]    [Inst C]    [Inst D]
ID_EX_IR              [Inst A]    [Inst B]    [Inst C]
EX_MEM_IR                         [Inst A]    [Inst B]
MEM_WB_IR                                     [Inst A]
```

### 2. Hazard Stalls & Flushes
Select `tb_risc_processor` -> `uut` -> `hazard_inst` in the SST panel and append:
- **`stall_F` / `stall_D`**: Goes high (`1`) when a Load-Use hazard is detected. In the waveform, you'll see `PC_val` and `IF_ID_IR` hold their values constant for an extra clock cycle (inserting a "bubble").
- **`flush_D` / `flush_E`**: Goes high (`1`) when a branch is taken. You will see the instructions inside `IF_ID_IR` or `ID_EX_IR` get cleared to `32'hd0000000` (`NOP`).
