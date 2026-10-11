# RISC-V 32-Bit Pipelined Processor Core

A modular 32-bit RISC-V (RV32I base integer ISA) pipelined processor core designed and implemented in SystemVerilog. The core includes hazard detection, forwarding, branch handling, Control and Status Registers (CSR) for interrupts, and optional UART peripheral integration.

---

## 🏛️ Architecture Overview

The core implements a multi-stage pipelined datapath with decoupled control and data units:

* **Instruction Fetch (IF):** Program counter generation with support for sequential execution, branch redirection, jump handling, and interrupt vectors (`epc_evec`).
* **Instruction Decode (ID):** Opcode and field decoding (R-type, I-type, S-type, B-type, U-type, J-type), immediate generator sign extension, and register file read (`x0-x31`).
* **Execute (EX):** Arithmetic Logic Unit (ALU) supporting arithmetic, bitwise, shift, set-less-than, and branch decision logic.
* **Memory Access (MEM):** Synchronous data memory interface supporting byte (`LB`/`SB`), half-word (`LH`/`SH`), and word (`LW`/`SW`) operations (signed and unsigned).
* **Writeback (WB):** Multiplexed writeback stage choosing between ALU result, data memory load value, or link register PC+4.

---

## ✨ Features

- **Pipelining & Hazards:** Dynamic pipeline stage registers between Fetch, Decode/Execute, and Memory/Writeback with hazard resolution and forwarding.
- **CSR & Interrupts:** Full machine-level Control and Status Register implementation (`mstatus`, `mie`, `mtvec`, `mip`, `mepc`, `mcause`) with interrupt handler support and `mret` execution.
- **UART Integration:** Hardware UART interface module for bidirectional serial communication.
- **Custom Firmware Assembler Flow:** Companion Python and GNU linker toolchain to compile bare-metal RISC-V assembly into simulation-ready hexadecimal memory files (`.mem`).

---

## 📂 Repository Structure

```text
riscv-pipelined-core/
├── rtl/
│   ├── constants.svh        # Opcode, ALU, branch, and memory control definitions
│   ├── pipeline.sv          # Baseline pipelined processor core
│   ├── pipeline_csr.sv      # Pipelined processor with CSR & interrupt support
│   └── pipeline_uart.sv     # Pipelined processor with UART integration
├── sim/
│   ├── testbench.sv         # Top-level testbench
│   └── mem/                 # Instruction & data memory images (.mem)
│       ├── csr_test.mem
│       ├── data_memory.mem
│       ├── gcd_instructions.mem
│       └── instruction_memory.mem
├── firmware/
│   ├── src/                 # Bare-metal assembly tests
│   │   ├── main.s           # CSR and interrupt test routine
│   │   └── startup.s        # Minimal vector/entry stub
│   ├── linker.ld            # Linker script for memory mapping
│   └── maketxt.py           # Converts binary images to 32-bit hex words
├── .gitignore
└── README.md
```

---

## 🛠️ Simulation & Verification

The core can be simulated using any standard SystemVerilog simulator (QuestaSim, ModelSim, Verilator, or Icarus Verilog):

1. **Include Search Path:** Ensure `rtl/` is on the preprocessor include path for `constants.svh`.
2. **Compile RTL and Testbench:**
   ```bash
   vlog +incdir+../rtl ../rtl/constants.svh ../rtl/pipeline_csr.sv testbench.sv
   ```
3. **Simulate:**
   ```bash
   vsim -c tb -do "run -all; quit"
   ```

---

## 🖋️ Author

* **GitHub:** [@samwork64](https://github.com/samwork64) / [@SameerArif64](https://github.com/SameerArif64)
