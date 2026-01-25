/*
 * For B_TYPE and JAL, branch_target is already computed.
 * For JAL, literally nothing needs to be executed, and it shouldn't be issued
 * to this FU.
 * For JALR, the computation of branch_target is all that needs to happen, and
 * since a register value is a source for this, it may need to get rs1 from
 * the CDB.
 * For branches, the computation that has to be performed is the comparison of
 * two register values, so rs1 and rs2 may both need to be retrieved from the
 * CDB.
 *
 * So basically, the operation performed on the operands is completely
 * different depending on whether this is a JALR or a branch.
 */
module branch_functional_unit #(parameter XLEN=32, parameter ROB_TAG_WIDTH) (
	input logic [XLEN-1:0]			v1,	// rs1
	input logic [XLEN-1:0]			v2,	// immediate for JALR, rs2 for B_TYPE

	input logic [XLEN-1:0]			pc,
	input logic [XLEN-1:0]			immediate,
	input logic [XLEN-1:0]			predicted_next_instruction,

	input logic [ROB_TAG_WIDTH-1:0]		rob_tag_in,

	input logic [2:0]			funct3,
	input logic				instruction_length,
	input logic				jalr,
	input logic				branch,
	// input logic		branch_prediction,

	output logic [XLEN-1:0]			next_instruction,
	output logic				redirect_mispredicted,

	output logic [ROB_TAG_WIDTH-1:0]	rob_tag_out,

	// reservation stations signals
	input logic				ready_to_execute,
	output logic				accept,

	output logic				write_to_buffer
	);

	logic [XLEN-1:0]	next_pc;
	assign next_pc = pc + (instruction_length ? XLEN'(4) : XLEN'(2));

	// JALR target computation
	logic [XLEN-1:0]	jalr_target;
	assign jalr_target = v1 + v2;	// unsure if I need to clear bit 0 or raise an exception

	// B_TYPE comparison
	// TODO: test EXTENSIVELY as you rewrote the branching logic

	// might be overkill defining these signals but I'm just ensuring it
	// gets synthesized how I want it
	logic			v1_eq_v2;
	logic 			v1_lt_v2;
	logic 			v1_ltu_v2;
	logic 			branch_comparison;	// the comparison used will be routed to this signal
	logic 			branch_taken;
	logic [XLEN-1:0]	branch_target;

	assign v1_eq_v2 = (v1 == v2);
	assign v1_lt_v2 = ($signed(v1) < $signed(v2));
	assign v1_ltu_v2 = (v1 < v2);


	always_comb begin
		case (funct3)
			3'b000,	// beq
			3'b001:	// bne
				branch_comparison = v1_eq_v2;
			3'b100,	// blt
			3'b101:	// bge
				branch_comparison = v1_lt_v2;
			3'b110,	// bltu
			3'b111:	// bgeu
				branch_comparison = v1_ltu_v2;
			default:	// invalid funct3, so for sure branch_taken will not be read
				branch_comparison = 0;
		endcase
	end
	assign branch_taken = branch_comparison ^ funct3[0];
	assign branch_target = branch_taken ? (pc + immediate) : next_pc;

	// select next_instruction based on jalr or branch, and evaluate
	// misprediction
	always_comb begin
		if (jalr)
			next_instruction = jalr_target;
		else if (branch)
			next_instruction = branch_target;
		else
			next_instruction = {XLEN{1'bx}};
	end
	assign redirect_mispredicted = next_instruction != predicted_next_instruction;

	assign rob_tag_out = rob_tag_in;

	// since FU is only attached to one RS, we accept when the operands
	// are ready
	assign accept = ready_to_execute;
	// since FU is combinational, we output the same cycle we accept the
	// instruction
	assign write_to_buffer = ready_to_execute;
endmodule
