# =============================================================================
# NexaCPU — Test runner (PowerShell)
# Usage: .\run_test.ps1 <milestone>
# Examples:
#   .\run_test.ps1 alu          — compile and run ALU testbench
#   .\run_test.ps1 register     — compile and run register file testbench
#   .\run_test.ps1 cpu          — compile and run full CPU testbench
#
# The script compiles with iverilog, runs with vvp, and optionally opens
# the resulting .vcd file in GTKWave if you pass -wave.
#
# Usage with waveform: .\run_test.ps1 alu -wave
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$milestone,
    [switch]$wave
)

# Map milestone names to their source files
$tests = @{
    "alu"          = @{
        tb  = "testbenches\alu_tb.v"
        src = @("src\alu.v")
        vcd = "alu.vcd"
    }
    "register"     = @{
        tb  = "testbenches\register_file_tb.v"
        src = @("src\register_file.v")
        vcd = "register_file.vcd"
    }
    "pc"           = @{
        tb  = "testbenches\program_counter_tb.v"
        src = @("src\program_counter.v")
        vcd = "program_counter.vcd"
    }
    "imem"         = @{
        tb  = "testbenches\instruction_memory_tb.v"
        src = @("src\instruction_memory.v")
        vcd = "instruction_memory.vcd"
    }
    "dmem"         = @{
        tb  = "testbenches\data_memory_tb.v"
        src = @("src\data_memory.v")
        vcd = "data_memory.vcd"
    }
    "control"      = @{
        tb  = "testbenches\control_unit_tb.v"
        src = @("src\control_unit.v")
        vcd = "control_unit.vcd"
    }
    "cpu"          = @{
        tb  = "testbenches\cpu_tb.v"
        src = @("src\alu.v", "src\register_file.v", "src\program_counter.v",
                "src\instruction_memory.v", "src\data_memory.v",
                "src\control_unit.v", "src\cpu.v")
        vcd = "cpu.vcd"
    }
}

if (-not $tests.ContainsKey($milestone)) {
    Write-Host "Unknown milestone: $milestone"
    Write-Host "Available: $($tests.Keys -join ', ')"
    exit 1
}

$t      = $tests[$milestone]
$vvp    = "testbenches\${milestone}_tb.vvp"
$srcFiles = ($t.src) -join " "
$cmd    = "iverilog -o $vvp $($t.tb) $srcFiles"

Write-Host ""
Write-Host "=== Compiling: $milestone ===" -ForegroundColor Cyan
Write-Host $cmd
Invoke-Expression $cmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "Compilation failed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Running simulation ===" -ForegroundColor Cyan
vvp $vvp
if ($LASTEXITCODE -ne 0) {
    Write-Host "Simulation failed." -ForegroundColor Red
    exit 1
}

# Move VCD file to waveforms/ directory if it exists
if (Test-Path $t.vcd) {
    $dest = "..\waveforms\$($t.vcd)"
    Move-Item -Force $t.vcd $dest
    Write-Host ""
    Write-Host "Waveform saved: $dest" -ForegroundColor Green
    if ($wave) {
        Write-Host "Opening GTKWave..." -ForegroundColor Cyan
        Start-Process gtkwave $dest
    }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
