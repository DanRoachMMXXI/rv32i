/*
 * using the data fields shown in the BOOM LSU
 * complete list here:
 * https://github.com/riscv-boom/riscv-boom/blob/master/src/main/scala/v4/lsu/lsu.scala#L174-L194
 * but many are not needed for my implementation
 */
interface load_buffer_entry #(parameter XLEN, parameter STQ_BUF_SIZE, parameter ROB_TAG_WIDTH);
	logic valid;
	logic [XLEN-1:0] address;
	logic address_valid;
	logic executed;
	logic succeeded;

	// not sure what these two do
	logic order_fail;
	logic observed;

	// bitmask that holds 1s for each entry in the store queue that this
	// load depends on.  If the data is present in the store queue, it is
	// to be forwarded.
	logic [STQ_BUF_SIZE-1:0] store_mask;
	logic forward_stq_data;		// BOOLEAN to indicate if we are forwarding
	logic [$clog2(STQ_BUF_SIZE)-1:0] forward_stq_index;

	// now here's the stuff that isn't in BOOM
	// if the store queue is going to broadcast to the CDB, it needs to
	// store the ROB index
	logic [ROB_TAG_WIDTH-1:0] rob_tag;
endinterface
