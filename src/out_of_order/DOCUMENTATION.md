# alu\_functional\_unit
- This module simply instantiates the ALU that was designed for the in-order microarchitectures,
  while providing the interface to the reservation station and CDB output buffer.  This interface
  was designed with pipelined functional units in mind, hopefully making it easier to implement
  pipelined functional units in the future.  The reservation station uses the `ready_to_execute`
  signal to indicate to the functional unit that its operands can be issued.  The functional unit
  responds with the accept signal to indicate that it is executing the instruction provided by the
  reservation station.  If there were multiple reservation stations attached to the same (pipelined)
  functional unit, this accept signal would be used to indicate which reservation station it sourced
  its operands from (in the form of some sort of a one-hot signal).  The `write_to_buffer` signal
  just tells the CDB output buffer whether the instruction at the last (or only) stage of the
  pipeline is valid, so that the CDB output buffer can store it and broadcast it to the CDB.

# cdb\_arbiter.sv
- This module just wraps a LSB fixed priority arbiter and uses the logical or of the request signal
  to indicate whether the value on the CDB is valid by driving the `cdb_valid` signal.

# cpu.sv
- This is the out-of-order processor in its whole, or at least what's been completed up to this
  point.
- Instantiates each submodule and connects them with pipelined signals
- This microarchitecture is parameterizable in the following ways
    - The number of ALU reservation stations
    - The number of AGU reservation stations
    - The number of branch/redirect reservation stations
    - The size of the reorder buffer
    - The size of the load and store queues in the LSU
    - The size of the return address stack
    - XLEN: the bit width of operands, although I've only ever tested anything with XLEN=32 bits
- The front-end pipeline:
    - Instruction Fetch
        - PC and `next_pc` logic
        - An asynchronous read ROM is serving as the instruction source for now.  In the future, the
          Instruction Fetch stage will be built out further with an Instruction Cache and interface
          with memory in a more realistic fashion.
    - Instruction Decode
        - Instantiation of the `instruction_decode` module, which uses a bunch of sub-modules to put
          all the control signals into the `control_signal_bus` struct.
        - Return Address Stack using the decoded instruction signals to push or pop return addresses
          and route them to the PC.
            - Eventually this will be moved into the Instruction Fetch stage to avoid the one-cycle
              stall incurred by predicting jumps in the decode stage
            - The design of the Return Address Stack was heavily guided by an LLM.
              TODO: move ^ to the section covering the RAS itself
    - Instruction and Operand Routing / Register File
        - Instantiate modules for the register file, instruction routing, and operand routing
            - Operand routing uses the tag and `tag_valid` stored in the register file to forward
              values from the ROB or the value present on the CDB
        - Access operands and out-of-order metadata from the register file
- Back end execution pipeline:
    - Generate blocks use the parameters that set the number of ALU, AGU, and branch/redirect
      reservation stations to generate an execution pipeline for each reservation station.  The
      execution pipeline consists of a reservation station, the functional unit, an output buffer,
      and a reset module for the reservation station that monitors the bus the output buffer
      broadcasts to.
    - The reorder buffer takes in allocation signals from the `instruction_route` module and monitors
      the CDB and AGU busses to indicate when instructions are ready to commit.
    - Load/Store Unit
        - TODO
    - Flushing
        - TODO

# functional\_unit\_output\_buffer
- This module was the solution recommended by an LLM to address competition for a shared data bus
  such as the CDB and AGU busses.  In hindsight, I could have just stalled the functional unit,
  especially in the case where the functional unit is pipelined, but it would require some
  modification to the interface between the reservation station and the functional unit, as well as
  it could possibly lengthen the critical path without some sort of pipelining/buffering anyways.
- The output buffer uses a free-slot picking algorithm to store entries, and broadcasts entries
  using a round-robin-esque algorithm that just keeps track of the last index that it broadcast, and
  selects the next valid index.

# instruction\_route.sv
## instruction\_route
- This module routes the instruction to the appropriate back-end units, ensuring that each
  dependency in the back-end is available and stalling the front-end if it can not issue the
  instruction to the back-end.
- Controls the allocation of entries in the `reorder_buffer` as well as the load and store queues in
  the `load_store_unit`.  If any of these queues are full, the front-end is stalled.
- Checks availability of the reservation station type that this instruction needs to be routed to
  and selects an available reservation station to store the operands, tags, and control signals.  If
  no reservation station of the correct type is available to store this instruction's data, the
  front-end is stalled.
## operand\_route
- Routes the correct values or tags of the instruction's operands to the reservation station based
  on the type of instruction.  Signal terminology is taken from the Hennessy & Patterson textbook
  Computer Architecture, a Quantitative Approach.  If the operand's value is available, `qN_valid`
  is cleared and the value is routed to `vN`.  If the operand's value is not available yet,
  `qN_valid` is set and the ROB tag for the instruction that produces this value is routed to `qN`.
- To find the operand, `operand_route` refers to the tag of the instruction stored in the
  `register_file` if the `tag_valid` signal is set in the RF.  If `tag_valid` is set,
  `operand_route` checks the `reorder_buffer` to see if the instruction is ready to commit,
  indicated by `rob_ready`.  If it's ready, the data is routed from the ROB.  Otherwise,
  `operand_route` also checks if the data is presently being broadcasted on the common data bus, and
  routes it from there if it's found.  If the data can't be sourced anywhere, `operand_route` routes
  the ROB tag of the instruction that generates the value to the RS, and `qN_tag_valid` is set.
## rob\_data\_in\_route
- Routes data to the `reorder_buffer` for the instruction being routed if the data is already
  available, as it is for the instructions `JAL`, `JALR`, `LUI`, and `AUIPC`.
- For `JAL` and `JALR`, this is how the link address is written to the `register_file`, as the
  actual execution in the branch/redirect execution unit computes the target address and broadcasts
  THAT to the common data bus.  More details on this available in the documentation for the
  branch/redirect execution unit.
- For `LUI` and `AUIPC`, this saves these instructions from needing to be routed to an execution
  unit.  This means the data becomes available in the ROB faster, and does not wastefully occupy a
  reservation station/execution unit nor unnecessarily stall if a reservation station is
  unavailable.

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

# pc\_mux
- This module is really more of a priority select to determine the next value of PC
- If an exception or misspeculation occurred, it takes the highest priority to update the PC to the
  evaluated correct next instruction or the instruction that needs to be retried.
- If a branch has been predicted taken, the branch target needs to be written to the PC.

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
