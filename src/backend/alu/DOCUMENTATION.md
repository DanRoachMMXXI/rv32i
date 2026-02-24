# alu
- This module contains the logic for arithmetic and logical operations for both R and I type
  instructions.  Using the `funct3` field of the instruction it selects the correct operation.
- Supported operations
    - addition
    - subtraction
    - left shift
    - signed less than comparison
    - unsigned less than comparison
    - bitwise exclusive or
    - logical right shift
    - arithmetic right shift
    - bitwise or
    - bitwise and
- The ALU also outputs a `zero` flag, which the `single_cycle` and `six_stage_pipeline`
  microarchitectures use to evaluate whether to perform a branch.
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
