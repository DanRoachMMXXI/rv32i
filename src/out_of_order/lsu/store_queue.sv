/*
 * what do
 * - allocate entries for store instructions w/ their rob tag (DONE)
 * - store address from AGU and mark address_valid (DONE)
 * - read data from the CDB (DONE)
 * - track which stores have committed from the rob (DONE)
 * - track when stores have succeeded (DONE)
 */
module store_queue #(parameter XLEN=32, parameter ROB_TAG_WIDTH, parameter STQ_SIZE, parameter STQ_TAG_WIDTH) (
	input logic clk,
	input logic reset,

	input logic					alloc_stq_entry,
	input logic [ROB_TAG_WIDTH-1:0]			rob_tag_in,
	input logic [XLEN-1:0]				store_data_in,	// store the data if it's already available
	input logic					store_data_in_valid,

	input logic					agu_address_valid,
	input logic [XLEN-1:0]				agu_address_data,
	input logic [ROB_TAG_WIDTH-1:0]			agu_address_rob_tag,

	input logic					rob_commit,
	input logic [ROB_TAG_WIDTH-1:0]			rob_commit_tag,

	input logic					flush,
	input logic [ROB_TAG_WIDTH-1:0]			flush_rob_tag,	// flush all instructions equal to and younger than this tag
	input logic [STQ_TAG_WIDTH-1:0]			stq_new_tail,

	input logic					store_fired,
	input logic [$clog2(STQ_SIZE)-1:0]		store_fired_index,	// DELIBERATELY LEAVING THIS AS INDEX

	input logic					store_succeeded,
	input logic [ROB_TAG_WIDTH-1:0]			store_succeeded_rob_tag,

	// CDB signals so we can read the store value for forwarding
	input logic					cdb_active,
	input wire [XLEN-1:0]				cdb_data,
	input wire [ROB_TAG_WIDTH-1:0]			cdb_tag,
	
	// vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
	// IF YOU ADD AN ENTRY HERE, PLEASE REMEMBER TO CLEAR IT IN THE
	// clear_entry FUNCTION!!!
	// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
	output logic [STQ_SIZE-1:0]			stq_valid,		// is the ENTRY valid
	output logic [STQ_SIZE-1:0][XLEN-1:0]		stq_address,
	output logic [STQ_SIZE-1:0]			stq_address_valid,
	output logic [STQ_SIZE-1:0][XLEN-1:0]		stq_data,
	output logic [STQ_SIZE-1:0]			stq_data_valid,	// is the data for the store present in the entry?
	output logic [STQ_SIZE-1:0]			stq_committed,
	// we need to track if we've executed this so we don't
	// issue it again while waiting for the succeeded signal
	output logic [STQ_SIZE-1:0]			stq_executed,
	output logic [STQ_SIZE-1:0]			stq_succeeded,
	output logic [STQ_SIZE-1:0][ROB_TAG_WIDTH-1:0]	stq_rob_tag,

	// status bits rotated such that the head is at index 0
	// useful for modules that select the youngest or oldest entries that
	// meet specific criteria using priority encoders
	output logic [STQ_SIZE-1:0]			stq_rotated_valid,	
	output logic [STQ_SIZE-1:0]			stq_rotated_address_valid,
	output logic [STQ_SIZE-1:0]			stq_rotated_data_valid,
	output logic [STQ_SIZE-1:0]			stq_rotated_committed,
	output logic [STQ_SIZE-1:0]			stq_rotated_executed,
	output logic [STQ_SIZE-1:0]			stq_rotated_succeeded,

	// circular buffer pointers
	output logic [STQ_TAG_WIDTH-1:0]		head,
	output logic [STQ_TAG_WIDTH-1:0]		tail,
	output logic					full

	// TODO: flush signals
	);

	localparam STQ_INDEX_WIDTH = $clog2(STQ_SIZE);
	logic [STQ_INDEX_WIDTH-1:0]	head_index;
	logic [STQ_INDEX_WIDTH-1:0]	tail_index;

	assign head_index = head[STQ_INDEX_WIDTH-1:0];
	assign tail_index = tail[STQ_INDEX_WIDTH-1:0];

	always_ff @ (posedge clk) begin
		if (!reset) begin
			head <= 0;
			tail <= 0;

			for (int i = 0; i < STQ_SIZE; i = i + 1) begin
				clear_entry(i[STQ_INDEX_WIDTH-1:0]);
			end
		end else begin
			if (flush) begin
				tail <= stq_new_tail;
			end
			for (int i = 0; i < STQ_SIZE; i = i + 1) begin
				if (flush && !($signed(stq_rob_tag[i] - flush_rob_tag) < 0)) begin: flush_entry
					clear_entry(i[STQ_INDEX_WIDTH-1:0]);
				end: flush_entry
				else begin: not_flush_entry
					// place a new store instruction in the store buffer
					if (alloc_stq_entry && !flush && i[STQ_INDEX_WIDTH-1:0] == tail_index) begin
						stq_valid[i] <= 1;
						stq_rob_tag[i] <= rob_tag_in;

						// if the data to store is already available,
						// store it in the queue
						// no need for a conditional since data_valid
						// will reflect if the data was avilable
						stq_data[i] <= store_data_in;
						stq_data_valid[i] <= store_data_in_valid;

						tail <= tail + 1;
					end

					if (stq_valid[i] && store_fired && i[STQ_INDEX_WIDTH-1:0] == store_fired_index) begin
						stq_executed[i] <= 1;
					end

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
						clear_entry(i[STQ_INDEX_WIDTH-1:0]);
						head <= head + 1;
					end
				end: not_flush_entry
			end
		end
	end

	// Since the tail pointer points to the next available entry in the
	// buffer, if that entry has the valid bit set, there are no more
	// available entries and the buffer is full.
	assign full = stq_valid[tail_index];

	assign stq_rotated_valid = (stq_valid >> head) | (stq_valid << (STQ_SIZE - head));
	assign stq_rotated_address_valid = (stq_address_valid >> head) | (stq_address_valid << (STQ_SIZE - head));
	assign stq_rotated_data_valid = (stq_data_valid >> head) | (stq_data_valid << (STQ_SIZE - head));
	assign stq_rotated_committed = (stq_committed >> head) | (stq_committed << (STQ_SIZE - head));
	assign stq_rotated_executed = (stq_executed >> head) | (stq_executed << (STQ_SIZE - head));
	assign stq_rotated_succeeded = (stq_succeeded >> head) | (stq_succeeded << (STQ_SIZE - head));

	function void clear_entry (logic [STQ_INDEX_WIDTH-1:0] index);
		stq_valid[index] <= 0;
		stq_address[index] <= 0;
		stq_address_valid[index] <= 0;
		stq_data[index] <= 0;
		stq_data_valid[index] <= 0;
		stq_committed[index] <= 0;
		stq_executed[index] <= 0;
		stq_succeeded[index] <= 0;
		stq_rob_tag[index] <= 0;
	endfunction
endmodule
