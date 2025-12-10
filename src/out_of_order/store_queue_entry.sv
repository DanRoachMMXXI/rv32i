interface store_queue_entry #(parameter XLEN);
	logic valid;
	logic [XLEN-1:0] address;
	logic address_valid;	// nothing says this is needed but why wouldn't it be?
	logic [XLEN-1:0] data;
	logic committed;	// signal received from the ROB
	logic succeeded;	// I assume we use this to clear the queue entry?
endinterface
