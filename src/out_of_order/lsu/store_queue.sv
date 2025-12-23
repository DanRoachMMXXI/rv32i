/*
 * what do
 * - allocate entries for store instructions w/ their rob tag (DONE)
 * - store address from AGU and mark address_valid (DONE)
 * - read data from the CDB (DONE)
 * - track which stores have committed from the rob (DONE)
 * - track when stores have succeeded (DONE)
 * - TODO: tell the ROB when a store is ready to commit
 *   - valid & address_valid & data_valid
 *   - NVM: the ROB will read the agu_address bus, and whenever
 *   agu_address_valid = 1 it will set an address_ready status bit at the
 *   ROB index of the tag
 */
module store_queue
	import lsu_pkg::*;
	(
	input logic clk,
	input logic reset,

	input logic alloc_stq_entry,
	input logic [ROB_TAG_WIDTH-1:0] rob_tag_in,
	input logic [XLEN-1:0] store_data_in,	// store the data if it's already available
	input logic store_data_in_valid,

	input logic agu_address_valid,
	input logic [XLEN-1:0] agu_address_data,
	input logic [ROB_TAG_WIDTH-1:0] agu_address_rob_tag,

	input logic rob_commit,
	input logic [ROB_TAG_WIDTH-1:0] rob_commit_tag,

	input logic store_succeeded,
	input logic [ROB_TAG_WIDTH-1:0] store_succeeded_rob_tag,

	// CDB signals so we can read the store value for forwarding
	input logic cdb_active,
	input logic [XLEN-1:0] cdb_data,
	input logic [ROB_TAG_WIDTH-1:0] cdb_tag,
	
	output store_queue_entry [STQ_SIZE-1:0] store_queue_entries,

	// circular buffer pointers
	output logic [$clog2(STQ_SIZE)-1:0] head,
	output logic [$clog2(STQ_SIZE)-1:0] tail,
	output logic full

	// TODO: flush signals
	);

	integer i;

	always_ff @ (posedge clk) begin
		if (!reset) begin
			head <= 0;
			tail <= 0;

			for (i = 0; i < STQ_SIZE; i = i + 1) begin
				clear_entry(i);
			end
		end else begin
			// place a new store instruction in the store buffer
			if (alloc_stq_entry) begin
				store_queue_entries[tail].valid <= 1;
				store_queue_entries[tail].rob_tag <= rob_tag_in;

				// if the data to store is already available,
				// store it in the queue
				// no need for a conditional since data_valid
				// will reflect if the data was avilable
				store_queue_entries[tail].data <= store_data_in;
				store_queue_entries[tail].data_valid <= store_data_in_valid;

				tail <= tail + 1;
			end

			for (i = 0; i < STQ_SIZE; i = i + 1) begin
				if (store_queue_entries[i].valid
						&& agu_address_valid
						&& agu_address_rob_tag == store_queue_entries[i].rob_tag) begin
					store_queue_entries[i].address <= agu_address_data;
					store_queue_entries[i].address_valid <= 1;
				end

				if (store_queue_entries[i].valid
						&& cdb_active
						&& cdb_tag == store_queue_entries[i].rob_tag) begin
					store_queue_entries[i].data <= cdb_data;
					store_queue_entries[i].data_valid <= 1;
				end

				if (store_queue_entries[i].valid
						&& rob_commit
						&& rob_commit_tag == store_queue_entries[i].rob_tag) begin
					store_queue_entries[i].committed <= 1;
				end

				if (store_queue_entries[i].valid
						&& store_succeeded
						&& store_succeeded_rob_tag == store_queue_entries[i].rob_tag) begin
					store_queue_entries[i].succeeded <= 1;
				end

				// if the entry at the head of the queue is
				// succeeded, clear it and increment the head
				// pointer
				if (store_queue_entries[i].valid && store_queue_entries[i].succeeded) begin
					clear_entry(i);
					head <= head + 1;
				end
			end
		end
	end

	// Since the tail pointer points to the next available entry in the
	// buffer, if that entry has the valid bit set, there are no more
	// available entries and the buffer is full.
	assign full = store_queue_entries[tail].valid;

	function void clear_entry (integer index);
		store_queue_entries[index].valid <= 0;
		store_queue_entries[index].address <= 0;
		store_queue_entries[index].address_valid <= 0;
		store_queue_entries[index].data <= 0;
		store_queue_entries[index].data_valid <= 0;
		store_queue_entries[index].committed <= 0;
		store_queue_entries[index].succeeded <= 0;
		store_queue_entries[index].rob_tag <= 0;
	endfunction
endmodule
