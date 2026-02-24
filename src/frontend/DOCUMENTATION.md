# control\_signal\_bus
- Packed typedef to consolidate all the control signals decoded in the Instruction Decode stage
- The typedef contains the following fields
    - `funct3`: `instruction[14:12]`, this is used to differentiate between the different R type, I
      type, and B type instructions.  For R and I type instructions, this is sent to the ALU.  B
      type instructions use this field to perform the correct comparison.
    - `valid`: boolean indicating whether the instruction is valid.  I implemented this for a few
      reasons.
        - When the pipeline resets or flushes, the valid bit is cleared ensuring nothing is routed.
        - When an instruction folds, the decode stage can clear the valid bit in the route stage,
          preventing the folded instruction from being routed to any modules in the backend.
    - `instruction_length`: boolean indicating whether the instruction is four bytes long or two
      bytes long (as in the RISC-V C extension for compressed instructions, which is not yet
      supported in this project).  This is almost always used to determine the value of the next PC.
    - `rs1_index`: `instruction[19:15]`.  Instructions that don't use rs1 do not route this value to
      anything
    - `rs2_index`: `instruction[24:20]`.  Instructions that don't use rs2 do not route this value to
      anything
    - `rd_index`: `instruction[11:7]`.  Instructions that do not write back to the `register_file`
      (stores) do not write to whatever value was in this field, as the `write_en` port of the RF
      will not be set.
    - `alu_op1_src`: multiplexer input for the `single_cycle` and `six_stage_pipeline`
      microarchitectures that routes the first operand for the ALU
    - `alu_op2_src`: multiplexer input for the `single_cycle` and `six_stage_pipeline`
      microarchitectures that routes the second operand for the ALU
    - `rd_select`: multiplexer input for the `single_cycle` and `six_stage_pipeline`
      microarchitectures that selects the source for the value written back to the `register_file`.
    - `sign`: an additional control bit sent to the ALU used to negate the second operand for
      addition and to enable sign extension for right shift.  This is just `instruction[30]` for
      those respective instructions.  Only used on the R type instructions.
    - `branch`: boolean indicating whether the instruction is a B type instruction (a conditional
      jump).
    - `branch_if_zero`: boolean indicating whether to jump if the `zero` output of the `alu` is set
      or cleared.  This is only used by the `single_cycle` and `six_stage_pipeline`
      microarchitectures.
    - `jump`: boolean indicating whether the instruction is an unconditional jump (JAL and JALR).
    - `jalr`: boolean indicating whether the instruction is an indirect unconditional jump (JALR).
    - `lui`: boolean indicating whether the instruction is LUI
    - `auipc`: boolean indicating whether the instruction is AUIPC
    - `u_type`: boolean indicating whetherh the instruction is of the U type format (LUI or AUIPC).
    - `rf_write_en`: boolean indicating whether to write the value routed to the `register_file`.
      This is only used by the `single_cycle` and `six_stage_pipeline` microarchitectures.  The
      `out_of_order` microarchitecture instead uses the `instruction_type` stored in the
      `reorder_buffer`.
    - `mem_write_en`: boolean indicating whether to write the value to memory this clock cycle.
      This is only used by the `single_cycle` and `six_stage_pipeline` microarchitectures that are
      using the `read_write_async_memory` module to model data memory.
    - `instruction_type`: 2-bit encoded signal for the `out_of_order` microarchitecture to know
      where to route the instruction and how to update its `reorder_buffer` entry.
    - `alloc_rob_entry`: boolean indicating whether the instruction should have a `reorder_buffer`
      entry allocated.  This gets cleared in the Instruction Route stage if an instruction is folded
      into the next.
    - `alloc_ldq_entry`: boolean indicating whether the instruction should have a `load_queue` entry
      allocated.  Obviously this is only set for load instructions.
    - `alloc_stq_entry`: boolean indicating whether the instruction should have a `store_queue`
      entry allocated.  Likewise this is only set for store instructions.
    - `fold`: boolean indicating whether the instruction in the Instruction Decode stage is folding
      the instruction in the Instruction Route stage.  THIS is currently the signal passed to the
      `instruction_route.valid` port to prevent it from routing and allocating a `reorder_buffer`
      entry when its instruction is folded.  `fold` is also currently hardwired to `1'b0` because
      folding logic is not yet implemented.
    - `op1_src`: 2-bit signal for the `operand_route` module to route the correct value and tag to
      `v1` and `q1`.  Currently routes a hardwired 0, the PC, and rs1.
    - `op2_src`: 2-bit signal for the `operand_route` module to route the correct value and tag to
      `v2` and `q2`.  Currently routes a hardwired 0, the decoded immediate, and rs2.

# instruction\_decode.sv
## immediate\_decode
- This module encapsulates the logic for decoding the immediate from supported instruction types.
  Instructions without an immediate value (R type) default to 0, but this would not get routed to
  anything that modifies the architectural state anyways.
## branch\_decode
- This module sets the redirect related control signals `branch`, `branch_if_zero`, `jump`, and
  `jalr` from the instruction's `opcode` and `funct3` fields.
## alu\_decode
- This module sets the alu control signals `sign`, `alu_op1_src`, and `alu_op2_src`.  Note that the
  ALU operand sources are only used by the in-order microarchitectures, and may end up being
  removed, causing this entire module to be removed.  This used to contain logic which mapped the B
  type `funct3` fields to the corresponding R type `funct3` encoding which controls the ALU.  The
  removal of this logic was necessary to ensure that the I had correctly removed all references to
  this in the out-of-order microarchitecture, but has left the in-order microarchitectures broken.
  The in-order microarchitectures will be updated to use the same encoding as the out-of-order
  implementation.
## out\_of\_order\_decode
- This module encapsulates all of the decode signals specific to the out-of-order microarchitecture.
  This sets the `instruction_type`, `alloc_rob_entry`, `alloc_ldq_entry`, `alloc_stq_entry`,
  `op1_src`, and `op2_src` singals of the `control_signal_bus`.
## instruction\_decode
- This module instantiates all of the other decode submodules as well as assigning miscellaneous
  signals including
    - `funct3`
    - `valid`
    - `fold`
    - `instruction_length`
    - `rs1_index`
    - `rs2_index`
    - `rd_index`
    - `rd_select`
    - `rf_write_en`
    - `mem_write_en`
    - `lui`
    - `auipc`
    - `u_type`

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

# pc\_mux
- This module is really more of a priority select to determine the next value of PC
- If an exception or misspeculation occurred, it takes the highest priority to update the PC to the
  evaluated correct next instruction or the instruction that needs to be retried.
- If a branch has been predicted taken, the branch target needs to be written to the PC.

# register\_file.sv
## register\_file
- Canonical register file.  Reads `rs1` and `rs2` based on the indices provided, writes the value of `rd`
  to the `rd_index` provided if `write_en` is set.
## rf\_rob\_tag\_table
- Tracks the `reorder_buffer` tag of the youngest in-flight instruction that will write to each
  register.  When an instruction commits and its value is written to the `register_file`, the
  `tag_valid` bit will be cleared if the tag of the comitting instruction matches the youngest tag
  stored, otherwise the tag remains valid because there is a younger in-flight instruction that
  needs to forward its data to dependent instructions.
