# cdb\_arbiter.sv
- This module just wraps a LSB fixed priority arbiter and uses the logical or of the request signal
  to indicate whether the value on the CDB is valid by driving the `cdb_valid` signal.

# functional\_unit\_output\_buffer
- This module was the solution recommended by an LLM to address competition for a shared data bus
  such as the CDB and AGU busses.  In hindsight, I could have just stalled the functional unit,
  especially in the case where the functional unit is pipelined, but it would require some
  modification to the interface between the reservation station and the functional unit, as well as
  it could possibly lengthen the critical path without some sort of pipelining/buffering anyways.
- The output buffer uses a free-slot picking algorithm to store entries, and broadcasts entries
  using a round-robin-esque algorithm that just keeps track of the last index that it broadcast, and
  selects the next valid index.

# memory\_address\_functional\_unit
- Similar to the `alu_functional_unit`, the AGU is a wrapper around a simple addition operation to
  compute the memory address for load and store instructions.
- The AGU does NOT broadcast its results to the common data bus.  Memory addresses are broadcasted
  to a dedicated address bus.  I designed it this way for a few reasons:
    - Memory addresses are never the value committed to the architectural state, and thus never
      directly consumed by other instructions that would be reading the CDB.
    - Store instructions do not commit their architectural state change to any regisers, so whether
      they use the CDB or not is somewhat irrelevant.  Loads DO commit their state change to
      registers, so broadcasting the address result to the CDB for a load instruction adds ambiguity
      as to whether the value with the tag is the load's address or the actual data that was loaded.
    - Broadcasting addresses to the CDB would also occupy additional CDB bandwidth
    - The reservation stations associated with the AGU execution units can be cleared when the
      address is computed and broadcast, and do not need to wait for the result of the operation to
      be broadcast to the CDB.  This fact, combined with the fact that I created a separate reset
      module for reservation stations to allow them to read a specific bus, allows AGU reservation
      stations to clear themselves when they observe their instruction's ROB tag on the  dedicated
      address bus, while all other reservation stations will reset themselves when they observe
      their instruction's ROB tag on the CDB.

# reorder\_buffer.sv
## reorder\_buffer module
- A canonical reorder buffer, a circular queue which tracks all of the instructions that have been
  issued to the back-end and commits their architectural state changes in program order.
- The following data is stored for each entry in the ROB:
    - `rob_valid`: boolean indicating whether the entry is valid
        - An LLM suggested moving away from valid bits in favor of using techniques such as element
          counters and extended pointers/tags.  I have implemented most of these features, but have
          yet to remove all references to these valid bits to remove them entirely.
    - `rob_instruction_type`: A 2-bit field indicating whether the instruction is an ALU
      instruction, branch/redirect instruction, LOAD instruction or STORE instruction.  The ROB uses
      this field to determine the following things
        - if `rob_instruction_type` shows the instruction is a STORE, `rob_ready` will be set when
          the entry's tag is seen on the address bus instead of the data bus, indicating that the
          store's address is computed and ready in the store queue.
        - if `rob_instruction_type` shows the instruction is a branch/redirect, the data broadcast
          on the CDB will be stored in `rob_next_instruction` instead of `rob_value`, which gets
          routed to the PC in the event of a misprediction.
        - commit logic uses this to enable writeback to the register file for any instruction that
          `rob_instruction_type` doesn't indicate to be a STORE.
    - `rob_destination`: the register index of the destination
    - `rob_value`: the value to be written to the destination register
        - STORE instructions do not route this value to memory.  The data to be written to memory is
          stored in the `store_queue` inside the `load_store_unit`
    - `rob_ready`: boolean indicating whether the instruction is ready to commit
        - This value can be set when an entry is allocated (see [[rob\_data\_in\_route]]), when the
          ROB entry's tag appears on the CDB if the instruction is NOT a store, and when the ROB
          entry's tag appears on the address bus if the instruction is a store.
    - `rob_branch_mispredict`: boolean status bit indicating if this entry stores a branch
      instruction that was evaluated to be mispredicted
        - This bit gets used to cause a flush and load the correct next instruction to the PC
    - `rob_uarch_exception`: boolean status bit indicating if a microarchitectural exception
      occurred (ex. memory ordering failure)
        - Thit bit gets used to cause a flush and load this instruction into the PC to be retried
    - `rob_arch_exception`: boolean status bit indicating if an architectural exception occurred
        - This does nothing, as I've not yet implemented handling for the exceptions defined in the
          RISC-V unprivileged ISA.
        - This will also likely be replaced by a single bit and an tag tracking the oldest excepting
          instruction.
    - `rob_next_instruction`: the instruction to be routed to the PC in the event of a flush
        - for branches/redirects that are mispredicted, this is the correct next instruction
        - for microarchitectural exceptions (ex. memory ordering failures), this is the excepting
          instruction that needs to retry execution.
    - `rob_ldq_tail`: the tail of the `load_queue` inside the `load_store_unit` to restore in the
      event of a flush
    - `rob_stq_tail`: the tail of the `store_queue` inside the `load_store_unit` to restore in the
      event of a flush
## buffer\_flusher module
- Logic that analyzes the `rob_branch_mispredict` and `rob_uarch_exception` status bits of the ROB
  to determine whether to flush and the oldest instruction to flush.
- If the flush was caused by a microarchitectural exception, such as a memory ordering failure, the
  excepting instruction needs to retry execution.  If the flush was caused by a mispredicted
  redirect, the redirect does not need to be re-executed, all the following instructions need to be
  flushed.
- Becuase this module is looking at the status bits of every ROB entry, it needs to evaluate the
  oldest excepting instruction.  To do so, it rotates the bits such that the ROB head is at index 0,
  then uses a priority encoder to find the least significant bit that's set, which is the
  oldest instruction that causes a flush.  This is far more complicated than it needs to be, and is
  just a result of a redesign of the ROB that I have yet to leverage to simplify the flushing logic.
  In the future, when the ROB sees any of these mispredict or exception status bits on the CDB, it
  shuold just store the tag of that and start the flush from there (or tag + 1 if it's a branch
  mispredict).

# reservation\_station.sv
## reservation\_station module
- The reservation station implements a typical Tomasulo reservation station, which stores the
  information needed to execute instructions.  The reservation station monitors the CDB to retrieve
  operands which have their `qN_valid` bit set, which indicates that the operands are not yet
  available.  When both operands are available `ready_to_execute` is set, and the attached
  functional unit will respond by setting an `accept` signal.  The reservation station sees that the
  functional unit accepted the instruction and stores that the instruction has been dispatched, so
  that it does not request the functional unit to accept it again.  In this implementation where all
  functional units are combinational and each reservation station is paired with its own functional
  unit, this just routes `ready_to_execute` back around to `dispatched`.  In the future, if timing
  analysis determines that I need to pipeline the functional units, I may attach multiple
  reservation stations to a single functional unit, where the functional unit will only be able to
  accept one operation per clock cycle, and it will have to inform the reservation station that it
  accepted the operation from.
## reservation\_station\_reset module
- The reset logic for the reservation station is contained in a separate module solely for the fact
  that reservation stations attached to different FUs may need to monitor different data busses to
  know when the execution result has been broadcast.  The reservation stations attached to the ALU
  and redirect FUs monitor the CDB, while the reservation stations attached to the AGUs need to
  monitor the dedicated address bus.  Separating the logic allows the reservation station to clearly
  specify the CDB to retrieve operands while allowing for a different bus to be wired to the reset
  module.  As an example, an AGU RS needs to retrieve operands from the CDB, but needs to clear
  itself when its ROB tag appears on the address bus.  An ALU FU is retrieving its operands from the
  CDB and clearing itself when its ROB tag appears on the CDB.
