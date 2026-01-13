// TODO: READ THE SECTION ON RETURN ADDRESS STACKS ON PG 31 AND 32 OF THE
// RISCV UNPRIVILEGED ISA.  IT HAS GOOD INFO ON WHEN TO PUSH/POP.
module return_address_stack #(parameter XLEN=32, parameter STACK_SIZE=16) (
	input logic clk,
	input logic reset,

	input logic [XLEN-1:0] address_in,
	input logic valid_in,	// are we performing an operation this cycle?
	input logic op,		// 0 = push, 1 = pop

	// if expanding to a superscalar processor, we need to repeat
	// ^ signals for each instruction that could be issued and execute
	// them in program order

	input logic checkpoint,	// on branch speculation, take a checkpoint of the current stack pointer
				// this is NOT when we take a JAL or JALR that interacts with the stack
	input logic restore_checkpoint,	// restore the stack pointer to the checkpointed stack pointer
					// this has to override checkpoint I think

	output logic address_out,
	output logic valid_out	// was the value on address_out popped last clock edge?
	);

	logic [XLEN-1:0][STACK_SIZE-1:0]	stack;
	logic [STACK_SIZE-1:0]			stack_valid;
	logic [$clog2(STACK_SIZE)-1:0]		stack_pointer;

	always @(posedge clk) begin
		// defaults: anything not a pop
		address_out <= 0;
		valid_out <= 0;

		if (restore_checkpoint) begin
			stack_pointer <= sp_checkpoint;
		end else if (checkpoint) begin
			sp_checkpoint <= stack_pointer;
		end else if (valid_in) begin
			if (op) begin	// pop
				address_out <= stack[stack_pointer - 1];
				valid_out <= stack_valid[stack_pointer - 1];

				stack[stack_pointer - 1] <= 0;
				stack_valid[stack_pointer - 1] <= 0;
				stack_pointer <= stack_pointer - 1;
			end else begin	// push
				stack[stack_pointer] <= address_in;
				stack_valid[stack_pointer] <= 1;
				stack_pointer <= stack_pointer + 1;
			end
		end
	end
endmodule
