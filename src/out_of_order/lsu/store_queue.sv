/*
 * what do
 * - allocate entries for store instructions w/ their rob tag (DONE)
 * - store address from AGU and mark address_valid (DONE)
 * - read data from the CDB (DONE)
 * - track which stores have committed from the rob (DONE)
 * - track when stores have succeeded (DONE)
 */
module store_queue
	import lsu_pkg::*;
	(
	input logic clk,
	input logic reset,

	input logic alloc_stq_entry,
	input logic [ROB_TAG_WIDTH-1:0] rob_tag_in,

	input logic agu_address_valid,
	input logic [XLEN-1:0] agu_address_data,
	input logic [ROB_TAG_WIDTH-1:0] agu_address_rob_tag,

	input logic rob_commit,
	input logic rob_commit_tag,

	input logic store_succeeded,
	input logic [ROB_TAG_WIDTH-1:0] store_succeeded_rob_tag,

	// CDB signals so we can read the store value for forwarding
	input logic cdb_active,
	input logic cdb_data,
	input logic cdb_tag,
	
	output store_queue_entry [STQ_SIZE-1:0] store_queue_entries,

	// circular buffer pointers
	output logic [$clog2(LDQ_SIZE)-1:0] head,
	output logic [$clog2(LDQ_SIZE)-1:0] tail

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
			if (alloc_ldq_entry) begin
				store_queue_entries[tail].valid <= 1;
				store_queue_entries[tail].rob_tag <= rob_tag_in;
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
				end;
			end
		end
	end

	function clear_entry (logic[$clog2(STQ_SIZE)-1:0] index);
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
