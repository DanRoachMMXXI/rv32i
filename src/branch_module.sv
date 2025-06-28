module branch_module #(parameter XLEN=32) (
	input logic [XLEN-1:0] pc,
	input logic [XLEN-1:0] immediate,

	input logic jump,
	input logic branch,

	output logic [XLEN-1:0] pc_next
	);

	logic [XLEN-1:0] target;
	
	assign target = pc + immediate;

	always_comb begin
		if (jump)
			pc_next = target;
		else if (branch)
			// this is where we will need to predict branch
			// for now, we'll do static:
			// predict taken if immediate is negative, predict not
			// taken if immediate is positive
			if ($signed(immediate) < 0)
				pc_next = target;
			else
				pc_next = pc;
		else
			pc_next = pc;
	end

endmodule
