@echo off
REM ============================================
REM Show RISC-V Processor Gate-Level Schematic
REM Usage: show_schematic.bat [module_name]
REM   No args  = show all modules (top-level)
REM   Example: show_schematic.bat execute_stage
REM ============================================

call "C:\oss-cad-suite\oss-cad-suite\environment.bat"
set PATH=C:\Program Files\Graphviz\bin;%PATH%

if "%~1"=="" (
    echo Generating top-level schematic...
    yosys -p "read_verilog fetch/fetch_stage.v; read_verilog decode/decode_stage.v; read_verilog execute/execute_stage.v; read_verilog memory/memory_stage.v; read_verilog hazard/hazard_unit.v; read_verilog risc_processor.v; hierarchy -top risc_processor; proc; opt; show -format dot -prefix output/view_schematic"
) else (
    echo Generating %~1 schematic...
    yosys -p "read_verilog fetch/fetch_stage.v; read_verilog decode/decode_stage.v; read_verilog execute/execute_stage.v; read_verilog memory/memory_stage.v; read_verilog hazard/hazard_unit.v; read_verilog risc_processor.v; hierarchy -top risc_processor; proc; opt; show -format dot -prefix output/view_schematic %~1"
)

echo Converting to SVG...
dot -Tsvg output\view_schematic.dot -o output\view_schematic.svg

echo Opening schematic...
start "" "output\view_schematic.svg"
