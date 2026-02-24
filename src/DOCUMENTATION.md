# out\_of\_order\_cpu.sv
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
