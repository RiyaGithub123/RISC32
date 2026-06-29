@echo off
REM ===================================================================
REM Run Custom RISC Processor Verification
REM Usage: run_verification.bat [program_name]
REM   Options: add, factorial
REM   Default: add
REM ===================================================================

REM Set environment for Icarus Verilog
if exist "C:\oss-cad-suite\oss-cad-suite\environment.bat" (
    call "C:\oss-cad-suite\oss-cad-suite\environment.bat"
) else (
    echo [WARNING] OSS CAD Suite environment.bat not found at C:\oss-cad-suite\oss-cad-suite\environment.bat
    echo Make sure iverilog and vvp are in your PATH.
)

set PROGRAM=%1
if "%PROGRAM%"=="" (
    set PROGRAM=add
)

if "%PROGRAM%"=="add" (
    echo Translating add.s...
    python riscv_translate.py add.s inst_data.mem
) else if "%PROGRAM%"=="factorial" (
    echo Translating factorial.s...
    python riscv_translate.py factorial.s inst_data.mem
) else (
    echo Unknown program: %PROGRAM%
    echo Supported programs: add, factorial
    exit /b 1
)

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Translation failed!
    exit /b %ERRORLEVEL%
)

echo Compiling Verilog design and testbench...
iverilog -o risc_sim.vvp fetch/fetch_stage.v decode/decode_stage.v execute/execute_stage.v memory/memory_stage.v hazard/hazard_unit.v risc_processor.v tb_risc_processor.v

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Verilog compilation failed!
    exit /b %ERRORLEVEL%
)

echo Running simulation...
vvp risc_sim.vvp

echo Verification complete.
