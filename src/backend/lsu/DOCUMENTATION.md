# load\_store\_unit
- The Load/Store Unit of this microarchitecture was heavily influenced by the design of the [Berkeley
  Out-of-Order Machine (BOOM)](https://docs.boom-core.org/en/latest/sections/load-store-unit.html),
  as many fine-grain details are not covered in the Hennessy and Patterson book from which I've
  studied Computer Architecture or my university's course curriculae.
# load\_queue
- The load queue is a circular buffer which stores data tracking all in-flight load operations.
- The `load_queue` stores the following data for each entry:
    - `ldq_valid`: boolean indicating whether this entry is valid
    - `ldq_address`: the address of the data to load
    - `ldq_address_valid`: boolean indicating whether `ldq_address` is valid, which is set when the
      `load_queue` sees the value stored in `ldq_rob_tag` on the dedicated address bus.
    - `ldq_sleeping`: boolean indicating whether the load has been put to sleep due to a dependence
      on a store from which it cannot forward data.
    - `ldq_sleep_rob_tag`: if a load is sleeping, this is the ROB tag of the store it needs to
      source its data from.  When this ROB tag commits, this load can be executed.
    - `ldq_executed`: boolean indicating if this load has been fired to memory.
    - `ldq_succeeded`: boolean indicating if this load has successfully returned data from memory.
    - `ldq_committed`: boolean indicating whether this load's ROB tag has committed from the reorder
      buffer.  Setting this causes the corresponding `load_queue` entry to be cleared the following
      clock edge.
    - `ldq_order_fail`: boolean indicating whether this load's execution has been identified to have
      violated memory ordering constraints.
    - `ldq_store_mask`: bitmask indicating which store operations in the `store_queue` that this
      load is dependent on.
    - `ldq_forwarded`: boolean indicating whether this load had its data forwarded from a store in
      the `store_queue`.
    - `ldq_forward_stq_tag`: if `ldq_forwarded` is set, this field contains the store queue tag of
      the store which forwarded the data for this load.
        - This is currently a bug, as my design has it such that stores do not broadcast anything to
          the CDB.  Instead, this will need to be set to the tag of the instruction that produces
          the data for the store, which is stored in `stq_data_producer_rob_tag`.
    - `ldq_rob_tag`: the ROB tag of this load instruction in the reorder buffer.
# load\_store\_dep\_checker
- This module implements one of the functions of BOOM's searcher: dependency checking for the firing
  load operation.  For each store queue entry, it checks if the firing load is dependent via the
  `ldq_store_mask`, if the store is valid via `stq_valid`, if the store has computed its address via
  `stq_address_valid`, and if the addresses are equal.  It then takes the vector representing which
  store queue entries meet that criteria and selects the youngest by rotating the vector by
  `stq_head` bits and using a MSB priority encoder, implemented in the `youngest_entry_select`
  module.
# lsu\_control
- The LSU control module is the logic that determines what pending memory operation to fire.
- The decision logic is as follows:
    - If the `store_queue` is full, fire the next pending store as this will help free entries in
      the `store_queue` more quickly.
    - If the `load_queue` is not empty, fire the next pending load as firing loads as early as
      possible provides a meaningful performance gain, whereas stores do not.
    - If the `store_queue` is not emtpy, fire the next pending store.
    - If both the load and store queues are empty, there's no entry to fire, so nothing is fired.
# order\_failure\_detector
- This module implements the other function of BOOM's searcher: order failure detection.  When a
  store commits, it checks against all valid loads (via `ldq_valid`) to check if the load has
  succeeded via `ldq_succeeded`, the load is dependent on this store via `ldq_store_mask`, the
  addresses match and the data was not forwarded or the data was forwarded from an older store.
  This combination of conditions means that the load retrieved stale data either from memory or from
  an older matching store in the `store_queue`.  This is only possible if the youngest dependent
  store's address was not computed when the load was evaluated by the `lsu_control`, so the
  `lsu_control` could not know that the load was going to load from the same address that the store
  was going to write to.
# store\_queue
- The store queue is a ciruclar buffer which stores data tracking all in-flight store operations.
- The `store_queue` stores the following data for each entry:
    - `stq_valid`: boolen indicating whether this entry is valid.
    - `stq_address`: the memory address of the location to store the data
    - `stq_address_valid`: boolean indicating whether `stq_address` is valid, which is set when the
      `store_queue` sees the value stored in `stq_rob_tag` on the dedicated address bus.
    - `stq_data`: the data to store in memory
    - `stq_data_valid`: boolean indicating whether the value in `stq_data` is valid, which is set
      when either when the entry is allocated in the queue or when the `store_queue` sees the tag
      stored in `stq_data_producer_rob_tag` on the CDB.
    - `stq_data_producer_rob_tag`: the ROB tag of the instruction that produces the data for this
      store.  This tag is only used to retrieve values from the CDB if `stq_data_valid` is not set.
    - `stq_committed`: boolean indicating whether this store's ROB tag has commtited from the
      reorder buffer.
    - `stq_executed`: boolean indicating whether this store has been fired to memory.
    - `stq_succeeded`: boolean indicating whether this store has successfully written data to
      memory.  Setting this causes the corresponding `store_queue` entry to be cleared the following
      clock edge.
    - `stq_rob_tag`: the ROB tag of this store instruction in the reorder buffer.
# youngest\_entry\_select
- This is a MSB priority encoder that rotates its input `queue_valid_bits` by `head_index` bits,
  resulting in the head of the queue to be located at index 0 before selecting the MSB as to find
  the youngest valid entry.
- This module was written when I was primarily relying on valid bits to track the status of each
  circular buffer entry (in the `load_queue`, `store_queue`, and `reorder_buffer`).  As such, I was
  heavily relying on rotations to perform age comparisons instead of using extended pointers.  Now
  that I'm primarily relying on extended pointers to perform age comparisons, I've removed most
  references to modules like this, but this is the last that I still need to try to rewrite to
  leverage the simpler age comparison I'm provided by extended pointers.
