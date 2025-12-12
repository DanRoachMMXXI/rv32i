/*
 * I had previously implemented this as a parameterized interface, which
 * caused quite a few problems for me.  I don't understand SystemVerilog well
 * enough yet to understand the problems.  Claude suggested creating a LDQ
 * package and defining the queue parameters and queue entry type in the
 * package.  This should work for my use case.
 */

/*
 * using the data fields shown in the BOOM LSU
 * complete list here:
 * https://github.com/riscv-boom/riscv-boom/blob/master/src/main/scala/v4/lsu/lsu.scala#L174-L194
 * but many are not needed for my design and implementation
 */
package lsu_pkg;
	parameter int XLEN=32;
	parameter int ROB_TAG_WIDTH=32;
	parameter int LDQ_SIZE=16;
	parameter int STQ_SIZE=16;

	typedef struct packed {
		logic valid;		// is the ENTRY valid
		logic [XLEN-1:0] address;
		logic address_valid;	// is the ADDRESS valid
		logic executed;		// load has been sent to memory
		logic succeeded;	// load has obtained its data through memory, cache, or store forwarding
		logic order_fail;	// has the searcher detected an ordering failure?
		// logic observed;	// "This load's memory effect is architecturally visible to other cores/threads" - Claude

		// bitmask that holds 1s for each entry in the store queue that this
		// load depends on.  If the data is present in the store queue, it is
		// to be forwarded.
		logic [STQ_SIZE-1:0] store_mask;
		logic forward_stq_data;		// BOOLEAN to indicate if we are forwarding
		logic [$clog2(STQ_SIZE)-1:0] forward_stq_index;

		// now here's the stuff that isn't in BOOM
		// if the store queue is going to broadcast to the CDB, it needs to
		// store the ROB index
		logic [ROB_TAG_WIDTH-1:0] rob_tag;
	} load_queue_entry;

	typedef struct packed {
		logic valid;		// is the ENTRY valid
		logic [XLEN-1:0] address;
		logic address_valid;
		logic [XLEN-1:0] data;
		logic data_valid;	// is the data for the store present in the entry?
					// need this for forwarding
		logic committed;
		logic succeeded;

		logic [ROB_TAG_WIDTH-1:0] rob_tag;
	} store_queue_entry;
endpackage
