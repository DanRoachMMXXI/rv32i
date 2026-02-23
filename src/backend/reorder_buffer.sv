// ROB_TAG_WIDTH >= $clog2(ROB_SIZE) MUST BE SATISFIED
// if ROB_TAG_WIDTH == $clog2(ROB_SIZE), it is unaware of wraparound
// occurrences
// if ROB_TAG_WIDTH == $clog2(ROB_SIZE) + 1, then it uses a phase bit
// if ROB_TAG_WIDTH > $clog2(ROB_SIZE) + 1, it contains further extended
// bits, and can use the sign of the subtraction of tags to compare their age
// TODO: use the above comparisons to implement age comparison logic
// throughout the processor.  it would be cool if the differences in tag
// widths were parameterizable so that performance comparisons could be more
// easily made in the future.
//
// TODO: do SOMETHING about arch_exceptions at the time of instruction commit,
// including flushing the ENTIRE ROB
module reorder_buffer #(
		parameter XLEN=32,
		parameter ROB_SIZE,
		parameter ROB_TAG_WIDTH,
		parameter LDQ_TAG_WIDTH,
		parameter STQ_TAG_WIDTH) (
	// Synchronous input signals
	input logic clk,
	input logic reset,	// active low

	// input signals for the instruciton to store in the buffer
	input logic		input_en,	// enable to read the values on the below signals
	input logic [1:0]	instruction_type_in,
	input logic [4:0]	destination_in,
	// This interface allows a value to be stored in the ROB at the time
	// of allocation, for instructions like LUI, AUIPC, JAL, etc.
	// Since they're issued in order, nothing will be waiting for them
	//
	// Stores also may have the value immediately ready, but need to have
	// their address calculated and read from the AGU address bus.
	input logic [XLEN-1:0]	value_in,
	input logic		ready_in,
	input logic [XLEN-1:0]	pc_in,
	input logic [LDQ_TAG_WIDTH-1:0]	ldq_tail_in,
	input logic [STQ_TAG_WIDTH-1:0]	stq_tail_in,
	
	// common data bus signals
	input logic			cdb_valid,
	input wire [XLEN-1:0]		cdb_data,
	input wire [ROB_TAG_WIDTH-1:0]	cdb_rob_tag,
	// microarchitectural exceptions: i.e. load ordering failures
	// these are retriable
	input wire			cdb_uarch_exception,
	// architectural excpetions: i.e. misaligned address
	// these need to trap to an exception handler and only do so at COMMIT
	input wire			cdb_arch_exception,
	// branch_mispredict is a signal associated with the values on the CDB,
	// but will only be produced by branch FUs and consumed by the ROB.
	// As the name implies: has the branch being broadcast on the CDB been
	// mispredicted?  When this is stored in the ROB, it will flush all
	// subsequent instructions and update the PC to the value that
	// appeared on cdb_data (and was stored in rob_next_instruction)
	input wire			branch_mispredict,

	// memory address bus - a separate bus where the AGU sends
	// addresses to the ROB for STORES ONLY
	input logic			agu_address_valid,
	input logic [XLEN-1:0]		agu_address_data,	// the address
	input logic [ROB_TAG_WIDTH-1:0]	agu_address_rob_tag,

	// flush signals	
	input logic				flush,
	input logic [ROB_TAG_WIDTH-1:0]		flush_start_tag,

	// the buffer itself
	output logic [ROB_SIZE-1:0]		rob_valid,
	output logic [ROB_SIZE-1:0][1:0]	rob_instruction_type,

	// destination is either the register index of rd or the memory
	// address that the value field will be written to.  whether it writes
	// to the register file or to memory is controlled by
	// instruction_type.
	output logic [ROB_SIZE-1:0][4:0]	rob_destination,
	// value stores the data that will be writted to the destination
	// field.  For ALU and memory instructions, this is the value that
	// appears on the CDB.  For branch instructions, this is PC+4, NOT the
	// value that appears on the CDB.
	output logic [ROB_SIZE-1:0][XLEN-1:0]	rob_value,

	// ready is set at any of the folowing times:
	// - when the entry is allocated if the data is already available (ex: LUI)
	// - when the ROB tag appears on the active CDB for non-store instructions
	// - when the ROB tag appears on the active address bus for store instructions
	output logic [ROB_SIZE-1:0]		rob_ready,
	output logic [ROB_SIZE-1:0]		rob_branch_mispredict,
	output logic [ROB_SIZE-1:0]		rob_uarch_exception,
	output logic [ROB_SIZE-1:0]		rob_arch_exception,

	// In the event of an exception, we need to be able to update the PC
	// to whatever instruction is correct.  In the case of an exception,
	// the next instruction to be executed (thus the next value of PC) is
	// the PC of the excepting instruction.  For branches, we store the
	// correct next_instruction in this field when it appears on the CDB,
	// and update the PC if the branch was mispredicted
	output logic [ROB_SIZE-1:0][XLEN-1:0]	rob_next_instruction,

	// we store the load and store queue tails at the time of ROB entry
	// allocation so that they can be directly restored in the event of
	// a misprediction, microarchitectural exception, or architectural
	// exception.
	output logic [ROB_SIZE-1:0][LDQ_TAG_WIDTH-1:0]	rob_ldq_tail,
	output logic [ROB_SIZE-1:0][STQ_TAG_WIDTH-1:0]	rob_stq_tail,

	// the specific ROB entry being committed,
	// this is just rob_field[head], but I don't want to create an
	// entirely separate module to do this
	output logic				rob_commit_valid,
	output logic [1:0]			rob_commit_instruction_type,
	output logic [4:0]			rob_commit_destination,
	output logic [XLEN-1:0]			rob_commit_value,
	output logic				rob_commit_ready,
	output logic				rob_commit_branch_mispredict,
	output logic				rob_commit_uarch_exception,
	output logic				rob_commit_arch_exception,
	output logic [XLEN-1:0]			rob_commit_next_instruction,
	output logic [LDQ_TAG_WIDTH-1:0]	rob_commit_ldq_tail,
	output logic [STQ_TAG_WIDTH-1:0]	rob_commit_stq_tail,

	// circular buffer pointers
	// head needs to be output so that the buffer entry at head
	// can be processed when commit is set.
	// likely both head and tail will be needed for flushing the
	// buffer
	output logic [ROB_TAG_WIDTH-1:0] head,
	output logic [ROB_TAG_WIDTH-1:0] tail,

	output logic empty,
	output logic full,
	output logic commit
	);

	// these signals are just the actual indices of the head and tail
	// pointers, as well as the cdb and address busses, omitting the phase
	// bit, so that we can more directly use them to index the buffer
	localparam ROB_INDEX_WIDTH = $clog2(ROB_SIZE);
	logic [ROB_INDEX_WIDTH-1:0] head_index;
	logic [ROB_INDEX_WIDTH-1:0] tail_index;
	logic [ROB_INDEX_WIDTH-1:0] cdb_rob_tag_index;
	logic [ROB_INDEX_WIDTH-1:0] agu_address_rob_tag_index;
	assign head_index = head[ROB_INDEX_WIDTH-1:0];
	assign tail_index = tail[ROB_INDEX_WIDTH-1:0];
	assign cdb_rob_tag_index = cdb_rob_tag[ROB_INDEX_WIDTH-1:0];
	assign agu_address_rob_tag_index = agu_address_rob_tag[ROB_INDEX_WIDTH-1:0];

	logic [ROB_TAG_WIDTH-1:0]	n_elements;
	assign n_elements = tail - head;
	assign empty = (n_elements == 0);
	assign full = (n_elements == ROB_SIZE);

	always_ff @ (posedge clk) begin
		if (!reset) begin
			head <= 0;
			tail <= 0;

			// reset buffer contents
			// I think the only thing that matters is valid = 0
			for (int i = 0; i < ROB_SIZE; i = i + 1) begin
				clear_entry(i[ROB_INDEX_WIDTH-1:0]);
			end
		end else begin
			if (flush)
				tail <= flush_start_tag;

			// store a new instruction in the buffer
			for (int i = 0; i < ROB_SIZE; i = i + 1) begin
				if (flush && !($signed(i[ROB_TAG_WIDTH-1:0] - flush_start_tag) < 0)) begin: flush_entry
					clear_entry(i[ROB_INDEX_WIDTH-1:0]);
				end: flush_entry
				else begin: not_flush_entry
					if (input_en && !flush && i[ROB_INDEX_WIDTH-1:0] == tail_index) begin
						rob_valid[i] <= 1;
						rob_instruction_type[i] <= instruction_type_in;
						rob_destination[i] <= destination_in;
						rob_value[i] <= value_in;
						rob_ready[i] <= ready_in;
						rob_next_instruction[i] <= pc_in;
						rob_ldq_tail[i] <= ldq_tail_in;
						rob_stq_tail[i] <= stq_tail_in;

						tail <= tail + 1;
					end

					// read a value off the CDB
					if (rob_valid[i] && cdb_valid && i[ROB_INDEX_WIDTH-1:0] == cdb_rob_tag_index) begin
						rob_uarch_exception[i] <= cdb_uarch_exception;
						rob_arch_exception[i] <= cdb_arch_exception;
						rob_branch_mispredict[i] <= branch_mispredict;
						// if an exception occurred, everything else is irrelevant, this
						// instrution will be flushed and retried it is then also critical
						// that we do NOT execute the below logic for a branch because we do
						// not want to overwrite the value in next_instruction since we need
						// to retry the execution of the branch. If branches can ever incur
						// a microarchitectural exception, this needs to be updated to also
						// not execute if cdb_uarch_exception == 1

						if (!cdb_arch_exception && rob_instruction_type[i] == 'b01) begin
							// store the CDB value in next_instruction (this is routed to PC)
							rob_next_instruction[i] <= cdb_data;
						end else begin
							// else the CDB data is to be stored in the register file or memory.
							rob_value[i] <= cdb_data;
						end

						rob_ready[i] <= 1;
					end

					// for stores, verify the memory address has been calculated and set
					// ready, which will determine whether the instruction is ready to
					// commit.  previously, this block updated the rob_destination entry,
					// but I realized that the load is actually fired from the LSU, in
					// which the store queue stores the address, so it's not needed in
					// the ROB.
					if (rob_valid[i]
						&& agu_address_valid
						&& rob_instruction_type[agu_address_rob_tag_index] == 2'b11
						&& i[ROB_INDEX_WIDTH-1:0] == agu_address_rob_tag_index) begin
						rob_ready[agu_address_rob_tag_index] <= 1;
					end

					// instruction commit
					if (rob_valid[i] && i[ROB_INDEX_WIDTH-1:0] == head_index && commit) begin
						clear_entry(i[ROB_INDEX_WIDTH-1:0]);
						head <= head + 1;
					end
				end
			end
		end
	end

	assign commit = !empty && rob_ready[head_index];

	// values being committed if commit is set
	assign rob_commit_valid = rob_valid[head_index];
	assign rob_commit_instruction_type = rob_instruction_type[head_index];
	assign rob_commit_destination = rob_destination[head_index];
	assign rob_commit_value = rob_value[head_index];
	assign rob_commit_ready = rob_ready[head_index];
	assign rob_commit_branch_mispredict = rob_branch_mispredict[head_index];
	assign rob_commit_uarch_exception = rob_uarch_exception[head_index];
	assign rob_commit_arch_exception = rob_arch_exception[head_index];
	assign rob_commit_next_instruction = rob_next_instruction[head_index];
	assign rob_commit_ldq_tail = rob_ldq_tail[head_index];
	assign rob_commit_stq_tail = rob_stq_tail[head_index];

	function void clear_entry(logic[ROB_INDEX_WIDTH-1:0] index);
		rob_valid[index] <= 0;
		rob_instruction_type[index] <= 0;
		rob_destination[index] <= 0;
		rob_value[index] <= 0;
		rob_ready[index] <= 0;
		rob_branch_mispredict[index] <= 0;
		rob_uarch_exception[index] <= 0;
		rob_arch_exception[index] <= 0;
		rob_next_instruction[index] <= 0;
		rob_ldq_tail[index] <= 0;
		rob_stq_tail[index] <= 0;
	endfunction
endmodule

// TODO: also flush reservation stations holding misspecualted instructions
// - reservation_station_reset probably takes in the flush output from this
//   module and checks if the bit at index rs_rob_tag is set
// TODO: also remember to flush instructions in the decode/RF stages
module buffer_flusher #(parameter XLEN=32, parameter ROB_SIZE, parameter ROB_TAG_WIDTH, parameter LDQ_SIZE, parameter LDQ_TAG_WIDTH, parameter STQ_SIZE, parameter STQ_TAG_WIDTH) (
	// decided to not take in the valid signal for now, since I know
	// I designed the buffer to only update entries that are valid
	input logic [ROB_SIZE-1:0]			rob_branch_mispredict,
	input logic [ROB_SIZE-1:0]			rob_uarch_exception,
	input logic [ROB_TAG_WIDTH-1:0]			rob_head,
	// we have to use the identified exception to select the next
	// instruction to execute
	input logic [ROB_SIZE-1:0][XLEN-1:0]		rob_next_instruction,
	input logic [ROB_SIZE-1:0][LDQ_TAG_WIDTH-1:0]	rob_ldq_tail,
	input logic [ROB_SIZE-1:0][STQ_TAG_WIDTH-1:0]	rob_stq_tail,

	output logic					flush,	// bool - are we flushing the pipeline?  intended for front end

	// which instruction needs to be re-executed?
	output logic [XLEN-1:0]				exception_next_instruction,

	output logic [ROB_TAG_WIDTH-1:0]		flush_start_tag,	// also serves as rob_new_tail

	output logic [LDQ_TAG_WIDTH-1:0]		ldq_new_tail,
	output logic [STQ_TAG_WIDTH-1:0]		stq_new_tail
);
	// I opted to rotate both mispredicted and exception so that once the
	// index of the oldest instruction causing a flush is found, we can
	// compare it against rotated_uarch_exception to see if that instruction is
	// an exception.  This is important in determining if we need to flush
	// that instruction from the ROB.  If it's an exception, it needs to
	// be flushed from the ROB.  If it's just a branch misprediction, it
	// must remain in the ROB so that it can commit.
	logic [ROB_SIZE-1:0]	rotated_mispredict;
	logic [ROB_SIZE-1:0]	rotated_uarch_exception;
	logic [ROB_SIZE-1:0]	rotated_mispredict_or_exception;	// this is used to find the index of the ROB entry that needs to be flushed
	logic [ROB_SIZE-1:0]	rob_rotated_flush;

	localparam ROB_INDEX_WIDTH = $clog2(ROB_SIZE);
	logic [ROB_INDEX_WIDTH-1:0]	rob_head_index;
	logic [ROB_INDEX_WIDTH-1:0]	rotated_oldest_exception_index;
	logic [ROB_INDEX_WIDTH-1:0]	oldest_exception_index;
	logic [ROB_INDEX_WIDTH-1:0]	rotated_flush_start_index;	// what index does the flush actually start from?

	assign rob_head_index = rob_head[ROB_INDEX_WIDTH-1:0];
	assign rotated_mispredict = (rob_branch_mispredict >> rob_head_index) | (rob_branch_mispredict << (ROB_SIZE - rob_head_index));
	assign rotated_uarch_exception = (rob_uarch_exception >> rob_head_index) | (rob_uarch_exception << (ROB_SIZE - rob_head_index));
	assign rotated_mispredict_or_exception = rotated_mispredict | rotated_uarch_exception;

	lsb_priority_encoder #(.N(ROB_SIZE)) oldest_exception_finder /* idk man */ (
		.in(rotated_mispredict_or_exception),
		.out(rotated_oldest_exception_index),
		.valid(flush)
	);

	assign oldest_exception_index = rotated_oldest_exception_index + rob_head_index;
	assign exception_next_instruction = rob_next_instruction[oldest_exception_index];

	// if the instruction that caused the flush was an exception, the
	// flush begins at the index of that instruction.  if the flush was
	// caused by a branch misprediction, the flush starts at the index of
	// the instruction following the branch (the branch result is still
	// valid and thus needs to commit).
	assign rotated_flush_start_index = rotated_uarch_exception[rotated_oldest_exception_index] ? rotated_oldest_exception_index : rotated_oldest_exception_index + 1;

	// flush_start_index will become the new tail of the ROB
	// TODO: verify this works with phase bits/extended tags, and verify
	// the cast does NOT sign extend
	assign flush_start_tag = rob_head + ROB_TAG_WIDTH'(rotated_flush_start_index);

	// load and store queue flushing - just pull the old tails from the ROB
	assign ldq_new_tail = rob_ldq_tail[oldest_exception_index];
	assign stq_new_tail = rob_stq_tail[oldest_exception_index];
endmodule
