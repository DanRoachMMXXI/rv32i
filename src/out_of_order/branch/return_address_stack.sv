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
	input logic restore_checkpoint,	// restore the stack pointer to the checkpointed stack pointer
					// this has to override checkpoint I think

	output logic [XLEN-1:0]	address_out,
	output logic		valid_out,	// was the value on address_out popped last clock edge?

	// TODO: something about a full stack, either a signal or even just an
	// assertion would be nice for simulations

	// debug outputs - I don't think anything is going to read these other
	// than the tests
	output logic [STACK_SIZE-1:0][XLEN-1:0]		stack,
	output logic [STACK_SIZE-1:0]			stack_valid,
	output logic [$clog2(STACK_SIZE)-1:0]		stack_pointer,
	output logic [$clog2(STACK_SIZE)-1:0]		sp_checkpoint
	);


	always @(posedge clk) begin
		// defaults: anything not a pop
		address_out <= 0;
		valid_out <= 0;

		if (restore_checkpoint) begin
			stack_pointer <= sp_checkpoint;
		end else if (checkpoint) begin
			sp_checkpoint <= stack_pointer;
		end else begin
			if (pop) begin	// pop
				address_out <= stack[stack_pointer - 1];
				valid_out <= stack_valid[stack_pointer - 1];

				stack[stack_pointer - 1] <= 0;
				stack_valid[stack_pointer - 1] <= 0;
			end
	       		if (push) begin	// push
				stack[stack_pointer] <= address_in;
				stack_valid[stack_pointer] <= 1;
			end

			// stack pointer logic
			// I previously handled this in the push and pop
			// blocks, and in verilator it actually worked fine,
			// but I'm wary of other simulators causing the
			// assignment in the push block to overwrite the
			// assignment made in the pop block.  So I'm
			// specifying it explicitly here.
			if (pop && !push) begin
				stack_pointer <= stack_pointer - 1;
			end else if (!pop && push) begin
				stack_pointer <= stack_pointer + 1;
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
	input logic jump,	// control signal: is the instruction a jump?
	input logic jump_type,	// 0 = JAL, 1 = JALR

	input logic [4:0] rs1,
	input logic [4:0] rd,

	output logic push,
	output logic pop
);
	logic rd_match;
	logic rs1_match;

	assign rd_match = (rd == 1) || (rd == 5);
	assign rs1_match = (rs1 == 1) || (rs1 == 5);

	assign push = jump && rd_match;	// in all cases where rd == x1/x5, for both JAL and JALR, PC+4 is pushed onto the RAS
	assign pop = jump && jump_type == 1 && rs1_match && (	// only pop on JALR where rs1 matches
		!rd_match || (rd_match && rd == rs1)
	);
endmodule
