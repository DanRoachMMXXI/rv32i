# branch\_evaluator
- The `branch_evaluator` compares branch predictions to the result computed by the `alu`.  If the
  prediction did not match the computed result, it sets the `branch_mispredicted` signal which is
  used to route `next_instruction` to the PC.
- This module is only used by the `single_cycle` and `six_stage_pipeline` microarchitectures.

# branch\_predictor
- The simplest prediction algorithm that allowed me to build out the other features of the
  microarchitectures, and much more easily produce mispredicted branches.

# branch\_target
- Logic that just routes PC or rs1 to the address base and adds the immediate to it.  Indirect jumps
  (JALR) add the encoded immediate to rs1, all other jumps and branches add the encoded immediate to
  the PC of the instruction.

# branch\_functional\_unit
- Similar to the other functional units, the branch functional unit wraps the redirect logic around
  the interface between the reservation station and the CDB output buffer.
- This FU handles both branches and indirect jumps
    - Branches select a comparison operation based on the `funct3` control signal provided and use
      that signal to determine whether to route the `branch_target` to `next_instruction`, or just
      the next sequential value of PC.
    - Indirect jumps simply add the operands from the reservation station, and route that to
      `next_instruction` if the `jalr` control signal was set.
- This functional unit takes in the `predicted_next_instruction` and compares it to the evaluted
  `next_instruction` to determine whether a redirect was mispredicted
    - Branches could have mispredictions evaluated by just comparing the boolean values of
      `predicted_taken` and `taken`, but indirect jumps complicate this a bit more.  The prediction
      in this context is actually the destination, not whether or not it's taken, so we need to
      carry forward the destination to know whether it was predicted correctly.

# return\_address\_stack.sv
- The use of return address stacks is mentioned in the RISC-V unprivileged ISA in Section 2.5.1.
## return\_address\_stack module
- This module only contains the stack itself abstract of how it interfaces with RISC-V instructions.
  The techniques I used to implement this were advised by an LLM.  The stack uses a `stack_pointer` to
  track the top of the stack, and a counter `n_entries` to track the size of the stack.  This means
  that index 0 does not always correspond to the bottom of the stack.  The stack is full if
  `n_entries == STACK_SIZE` and empty if `n_entries == 0`.
- The RAS can store one checkpoint and restore that checkpoint using the `checkpoint` and
  `restore_checkpoint` signals respectively.  Checkpointing moves the value of `stack_pointer` into
  `sp_checkpoint` and `n_entries` into `n_entries_cp`.  Restoring the checkpoint is the reverse.
## ras\_control module
- The RAS control module contains the logic that controls the RAS based on the instruction being
  evaluated.  This implements the truth table found in Section 2.5.1 to decode JALR instruction
  hints.  If `rd` is ever `x1` or `x5`, the conventional return link registers, the stack will have
  the next sequential value of PC pushed onto it.  If the source register `rs1` for JALR is ever the
  conventional return link registers and are not equal to `rd`, it will pop a value off of the top
  of the stack.  If the instruction is making any speculations and is not being flushed, then a
  checkpoint is saved.
