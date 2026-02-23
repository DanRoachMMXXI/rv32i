# rv32i
SystemVerilog models of RISC-V microarchitectures implementing the RV32I instruction set.

This project is still very much an active work in progress.  Thus far, a single cycle microarchitecture and a six-stage pipelined microarchitecture have been implemented and simulated using small C programs compiled with the [RISC-V GNU Toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain).  These microarchitectures are synthesizeable and targeted for the [Artix 7 100T FPGA](https://docs.amd.com/v/u/en-US/ds181_Artix_7_Data_Sheet) on [this development board](https://www.digikey.com/en/products/detail/digilent-inc/410-319-1/9445912?so=95519513&content=productdetail_US&mkt_tok=MDI4LVNYSy01MDcAAAGdzCNrrIdgCMQNyOZ_Mlx2L1BlFObT9GSRlExVtJUz3MiDNERujRfGIrD6dpy938oVw2XEh_TentY6wYrEvwPcWJc0q7ngipHuUAcbN5oyHg) using Vivado.  The subcomponents have had UVM testbenches developed to verify them using constrained-random inputs.

## Generative AI Usage Statement
No SystemVerilog code in this repository was written by an LLM.  I have used generative AI in a few
other ways to develop the out of order microarchitecture.  Primarily, I've used LLMs to somewhat
replicate access to a knowledgeable and experienced mentor that can assist and teach me as I've
encountered problems that I didn't have the knowledge to solve.  As such, some design decisions were
made under the guidance of LLMs.  I will do my best to indicate which choices were made under the
guidance of LLMs, as well as the problems they aimed to solve.

## Implemented microarchitectures
- Single-issue out-of-order design using Tomasulo's algorithm with a reorder buffer and a Load/Store
  Unit, and a Return Address Stack for branch prediction
    - This is the primary focus of this repository
- Single-issue in-order six-stage pipeline
- Single cycle in-order design

## Future Work
- Highly accurate branch prediction
    - For the time being, the implemented microarchitectures are predicting branches taken if they're backwards jumps, and predicting branches not taken if they're forward jumps (as stated on Page 32 of the [RISC-V Unprivileged ISA](https://docs.riscv.org/reference/isa/_attachments/riscv-unprivileged.pdf) when branches are initially encountered).  The low accuracy of this method will be useful in validating how the microarchitectures handle mispredictions.  I'll be implementing prediction algorithms that maintain the history of branch instructions to improve the accuracy of these predictions.
    - Implementation of a Return Address Prediction Stack as described on Page 31 of the RISC-V Unprivileged ISA.
- Testing/Validation Enhancements
    - I intend to develop a test setup that enables me to track how the architectural state of the microarchitectures changes, regardless of their implementation details.
    - With this test setup, I'll also be developing a suite of C programs and the validation that tracks the architectural state changes to validate all microarchitecture implementations I create.
- Interfacing the microarchitectures with the RAM and ROM of the FPGA.
    - Currently, memory is implemented with asynchronous read (to make the initial implementations of the microarchitectures convenient).  Because of this, when synthesized these memories are implemented in the logic cells of the FPGA, which can not even support a few kilobytes of memory in this fashion.  I'll be changing these memories to small caches, and interfacing with the synchronous read RAM and ROM elements on the FPGA on cache misses.
