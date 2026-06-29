# EDA Playground Simulation & Pipelining Waveform Guide

This guide explains how to set up the pipelined processor simulation on **EDA Playground** and configure the **EPWave** waveform viewer to visually verify the pipeline stages and control flow.

---

## 🛠️ Step-by-Step EDA Playground Setup

1. **Open the Tool**: Navigate to [edaplayground.com](https://edaplayground.com).
2. **Configure left sidebar options**:
   - **Testbench + Design**: Set to `SystemVerilog/Verilog`.
   - **Top Entity**: Set to `tb_risc_processor`.
   - **Simulator**: Set to `Icarus Verilog 0.10.0` (or any available Icarus Verilog version).
   - **Open EPWave after run**: Check this box (critical for waveform analysis).
3. **Paste Design Code**:
   - Copy the consolidated design Verilog code and paste it into the **`design.sv`** tab.
4. **Paste Testbench Code**:
   - Copy the testbench Verilog code and paste it into the **`testbench.sv`** tab.
5. **Run the Simulation**:
   - Click the **Run** button at the top-left.

---

## 📉 Visualizing Pipelining in EPWave

Once the simulation completes, the **EPWave** tab will open. To visually verify that instructions are executed concurrently in a **5-stage pipeline**, you need to add specific signals to the wave diagram and arrange them in order.

### 1. Essential Signals to Add
In the signal selector (usually in the left pane of EPWave), navigate to `tb_risc_processor` -> `uut` and add these signals in this exact order:

| Signal Name | Description | Purpose in Pipelining |
| :--- | :--- | :--- |
| **`clk1`** & **`clk2`** | Dual-phase clocks | Shows clock cycles and phases driving the registers. |
| **`PC_val`** | Program Counter | Shows instruction addresses fetched sequentially. |
| **`IF_ID_IR`** | Instruction Fetch / Decode Register | Holds the instruction currently being decoded. |
| **`ID_EX_IR`** | Decode / Execute Register | Holds the instruction currently being executed in the ALU. |
| **`EX_MEM_IR`** | Execute / Memory Register | Holds the instruction currently interacting with data memory. |
| **`MEM_WB_IR`** | Memory / Writeback Register | Holds the instruction writing back to the register file. |

---

### 2. How the Waveform Proves Pipelining
When you look at the hex values of the instruction registers (`IF_ID_IR`, `ID_EX_IR`, `EX_MEM_IR`, `MEM_WB_IR`) in EPWave, you should see a **staircase pattern** as the instruction moves down the pipeline registers cycle-by-cycle:

```
Cycle:       1          2          3          4          5
===================================================================
IF_ID_IR  | [Inst A] | [Inst B] | [Inst C] | [Inst D] | [Inst E] |
ID_EX_IR  |          | [Inst A] | [Inst B] | [Inst C] | [Inst D] |
EX_MEM_IR |          |          | [Inst A] | [Inst B] | [Inst C] |
MEM_WB_IR |          |          |          | [Inst A] | [Inst B] |
```

#### Example (Simple Addition Program):
For the instructions:
* `Inst 0: 00410003` (`li x1, 3`)
* `Inst 1: 00810004` (`li x2, 4`)
* `Inst 2: 08c21000` (`add x3, x1, x2`)

In the waveform viewer, you will observe the value `00410003` appear in:
1. `IF_ID_IR` at cycle 1.
2. `ID_EX_IR` at cycle 2 (while `IF_ID_IR` receives the next instruction `00810004`).
3. `EX_MEM_IR` at cycle 3.
4. `MEM_WB_IR` at cycle 4.

This staggered progression proves that multiple instructions are being processed simultaneously in different stages.

---

### 3. Visualizing Pipeline Hazards & Stalls
To see how the hardware resolves hazards, add these signals from `tb_risc_processor` -> `uut` -> `hazard_inst`:

* **`stall_F` / `stall_D`**: Should go high (value `1`) when a Load-Use hazard is detected (e.g. loading a value from memory and immediately using it in the next instruction). In the waveform, you will see `PC_val` and `IF_ID_IR` hold their values constant for an extra cycle, inserting a "bubble".
* **`flush_D` / `flush_E`**: Should go high (value `1`) when a conditional or unconditional branch is taken. In the waveform, you will see the instruction register reset to `32'hd0000000` (`NOP`), indicating that incorrect speculatively fetched instructions were flushed.
