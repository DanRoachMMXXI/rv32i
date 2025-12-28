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
module store_queue #(parameter XLEN=32, parameter ROB_TAG_WIDTH=32, parameter STQ_SIZE=32) (
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
	
	output logic [STQ_SIZE-1:0] stq_valid,		// is the ENTRY valid
	output logic [STQ_SIZE-1:0] [XLEN-1:0] stq_address,
	output logic [STQ_SIZE-1:0] stq_address_valid,
	output logic [STQ_SIZE-1:0] [XLEN-1:0] stq_data,
	output logic [STQ_SIZE-1:0] stq_data_valid,	// is the data for the store present in the entry?
	output logic [STQ_SIZE-1:0] stq_committed,
	output logic [STQ_SIZE-1:0] stq_succeeded,
	output logic [STQ_SIZE-1:0] [ROB_TAG_WIDTH-1:0] stq_rob_tag,

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
				stq_valid[tail] <= 1;
				stq_rob_tag[tail] <= rob_tag_in;

				// if the data to store is already available,
				// store it in the queue
				// no need for a conditional since data_valid
				// will reflect if the data was avilable
				stq_data[tail] <= store_data_in;
				stq_data_valid[tail] <= store_data_in_valid;

				tail <= tail + 1;
			end

			for (i = 0; i < STQ_SIZE; i = i + 1) begin
				if (stq_valid[i] && agu_address_valid && agu_address_rob_tag == stq_rob_tag[i]) begin
					stq_address[i] <= agu_address_data;
					stq_address_valid[i] <= 1;
				end

				if (stq_valid[i] && cdb_active && cdb_tag == stq_rob_tag[i]) begin
					stq_data[i] <= cdb_data;
					stq_data_valid[i] <= 1;
				end

				if (stq_valid[i] && rob_commit && rob_commit_tag == stq_rob_tag[i]) begin
					stq_committed[i] <= 1;
				end

				if (stq_valid[i] && store_succeeded && store_succeeded_rob_tag == stq_rob_tag[i]) begin
					stq_succeeded[i] <= 1;
				end

				// if the entry at the head of the queue is
				// succeeded, clear it and increment the head
				// pointer
				if (stq_valid[i] && stq_succeeded[i]) begin
					clear_entry(i);
					head <= head + 1;
				end
			end
		end
	end

	// Since the tail pointer points to the next available entry in the
	// buffer, if that entry has the valid bit set, there are no more
	// available entries and the buffer is full.
	assign full = stq_valid[tail];

	function void clear_entry (integer index);
		stq_valid[index] <= 0;
		stq_address[index] <= 0;
		stq_address_valid[index] <= 0;
		stq_data[index] <= 0;
		stq_data_valid[index] <= 0;
		stq_committed[index] <= 0;
		stq_succeeded[index] <= 0;
		stq_rob_tag[index] <= 0;
	endfunction
endmodule
