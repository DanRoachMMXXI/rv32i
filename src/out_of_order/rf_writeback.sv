module rf_writeback (
	// bool - is an instruction being committed
	input logic		rob_commit,

	// the buffer entry being committed if rob_commit is set
	input logic		rob_commit_valid,
	input logic [1:0]	rob_commit_instruction_type,
	// input logic		rob_commit_address_valid,
	// input logic [XLEN-1:0]	rob_commit_destination,
	// input logic [XLEN-1:0]	rob_commit_value,
	// input logic		rob_commit_data_ready,
	// input logic		rob_commit_branch_mispredict,
	input logic		rob_commit_exception,
	// input logic [XLEN-1:0]	rob_next_instruction,

	output logic		rf_write_en
	// this doesn't have to signal to the STQ it's committing
	// the LDQ and STQ read the commit flag and the ROB tag to evaluate
	// that on their own

	// updating of PC is done by separate logic to handle branches
	// this is not being done at writeback since we want to update PC in
	// response to redirect execution as soon as possible
	// that logic must also work if the instruction is at the head of the
	// ROB anyways, so it doesn't need to be repeated here
);

	assign rf_write_en = rob_commit && rob_commit_valid	// this might be unnecessary
		&& rob_commit_instruction_type != 'b11	// everything that isn't a store can write to the RF
		&& !rob_commit_exception	// obviously don't want to commit if an exception occurred
		;
endmodule
