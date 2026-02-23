module return_address_stack #(parameter XLEN=32, parameter STACK_SIZE=16) (
	input logic clk,
	input logic reset,

	input logic [XLEN-1:0] address_in,
	// as seen above, it's possible that we need to pop and push in the
	// same cycle.  If both of these signals are set, the pop will be
	// performed first, then the push will be performed
	input logic push,
	input logic pop,

	// if expanding to a superscalar processor, we need to repeat
	// ^ signals for each instruction that could be issued and execute
	// them in program order

	input logic checkpoint,	// on branch speculation, take a checkpoint of the current stack pointer
				// this is NOT when we take a JAL or JALR that interacts with the stack
				// update: this could be a speculated JALR
	input logic restore_checkpoint,	// restore the stack pointer to the checkpointed stack pointer
					// this has to override checkpoint I think

	output logic [XLEN-1:0]	address_out,

	output logic		empty,
	output logic		full,

	// debug outputs - I don't think anything is going to read these other
	// than the tests
	output logic [STACK_SIZE-1:0][XLEN-1:0]		stack,
	output logic [$clog2(STACK_SIZE)-1:0]		stack_pointer,
	output logic [$clog2(STACK_SIZE)-1:0]		sp_checkpoint,
	// n_entries is effectively "how many valid elements are behind the
	// current stack pointer?"
	output logic [$clog2(STACK_SIZE):0]		n_entries,	// counter of entries
	output logic [$clog2(STACK_SIZE):0]		n_entries_cp	// checkpoint for the counter
	);

	assign empty = (n_entries == 0);
	assign full = (n_entries == STACK_SIZE);

	logic [$clog2(STACK_SIZE)-1:0]	sp_next;
	assign sp_next = stack_pointer - 1;

	assign address_out = stack[sp_next];

	always_ff @(posedge clk) begin
		if (!reset) begin
			stack <= 0;
			stack_pointer <= 0;
			sp_checkpoint <= 0;

			n_entries <= 0;
			n_entries_cp <= 0;
		end else begin
			if (restore_checkpoint) begin
				stack_pointer <= sp_checkpoint;
				n_entries <= n_entries_cp;
			end else if (checkpoint) begin
				sp_checkpoint <= stack_pointer;
				n_entries_cp <= n_entries;
			end

			if (push && pop) begin
				stack[sp_next] <= address_in;
				// stack pointer doesn't change, but if the
				// stack was empty, the push effectively
				// "allocated" the entry behind the stack
				// pointer, so we need to increment our
				// counter to stay aware that there's "one
				// valid element behind the stack pointer"
				n_entries <= empty ? n_entries + 1 : n_entries;
			end else if (pop) begin
				stack[sp_next] <= 0;
				stack_pointer <= sp_next;
				n_entries <= empty ? 0 : n_entries - 1;
			end else if (push) begin
				stack[stack_pointer] <= address_in;
				stack_pointer <= stack_pointer + 1;
				n_entries <= full ? STACK_SIZE : n_entries + 1;
			end
		end
	end
endmodule

// "hints as to the instructions' usage are encoded implicitly via the
// register numbers used." - RISC-V Unprivileged ISA
// JAL - pushes return address only when rd is x1 or x5
// JALR - push or pop as per the following:
// rd == x1/x5	rs1 == x1/x5	rd == rs1	what do
// no		no		X		nothing
// no		yes		X		pop
// yes		no		X		push
// yes		yes		no		pop, then push
// yes		yes		yes		push
//
// TODO: checkpoint and restore_checkpoint perhaps set by this module??
module ras_control (
	input logic branch,	// control signal: is the instructin a branch?  need to checkpoint
	input logic jump,	// control signal: is the instruction a jump?
	input logic jalr,	// 0 = JAL, 1 = JALR
	input logic jalr_fold,	// is the JALR being folded with a U_TYPE instruction, making it deterministic?

	input logic flush,	// if misspecualtion happened, this will restore the checkpoint

	input logic [4:0] rs1_index,
	input logic [4:0] rd_index,

	output logic push,
	output logic pop,
	output logic checkpoint,
	// restore_checkpoint might not need to be a port here,
	// flush/exception could just be routed to this on the RAS
	output logic restore_checkpoint
);
	logic rd_index_match;
	logic rs1_index_match;

	assign rd_index_match = (rd_index == 1) || (rd_index == 5);
	assign rs1_index_match = (rs1_index == 1) || (rs1_index == 5);

	assign push = jump && rd_index_match;	// in all cases where rd == x1/x5, for both JAL and JALR, PC+4 is pushed onto the RAS
	assign pop = jump && jalr && rs1_index_match && (	// only pop on JALR where rs1_index matches
		!rd_index_match || (rd_index_match && rd_index != rs1_index)
	);

	assign checkpoint = !flush && (branch || (jump && jalr && !jalr_fold));
	assign restore_checkpoint = flush;
endmodule
