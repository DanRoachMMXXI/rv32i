module instruction_route #(parameter XLEN=32, parameter N_ALU_RS, parameter N_AGU_RS, parameter N_BRANCH_RS) (
	// is the instruction at this stage actually getting executed?
	// valid should only be 0 in cases where the instruction is flushed or
	// folded (i.e., the U_TYPE instruction in this stage when an
	// overwriting JALR is decoded)
	// TODO: eventually I'll need to figure out how the route/RF stage
	// knows to flush its U_TYPE instruction when it's supposed to be
	// folded into a JALR.
	// Initially, I'm inclined to believe that valid can just be set to
	// 0 here based on the decoded signals in the decode stage, but timing
	// analysis will need to validate that approach to ensure it's not
	// causing too great of a delay.
	// I have written this module such that valid is only used at the very
	// end of each logic chain to minimize the impact that its dependency
	// on decode logic can have, still will need to analyze tho.
	input logic			valid,

	// these come from decode
	// branch and jalr need to be consumed because we do not want to route
	// a JAL to the functional unit.  we already have the value, and that
	// must be written to the ROB when the entry is allocated.
	// I've opted to assess this in the routing stage, because
	// instruction_type still needs to be the branch value for JALs still
	// need to be committed the same as branches and JALRs, which refers
	// to instruction_type to decide how to commit the ROB entry.
	// similarly, we need to know if this is a U type instruction, which
	// does not need to be issued to an ALU functional unit.  the value is
	// already available, and should be immediately written to the ROB
	input logic [1:0]		instruction_type,
	input logic			ctl_branch,
	input logic			ctl_jalr,
	input logic			ctl_u_type,
	// TODO: ideally come up with less repetitive names for these signals
	input logic			ctl_alloc_rob_entry,
	input logic			ctl_alloc_ldq_entry,
	input logic			ctl_alloc_stq_entry,

	input logic			rob_full,
	input logic			ldq_full,
	input logic			stq_full,

	// TODO: ensure nothing is allocated or routed if flush is set
	input logic			flush,	// was this instruction misspeculated?

	input logic [N_ALU_RS-1:0]	alu_rs_busy,
	input logic [N_AGU_RS-1:0]	agu_rs_busy,
	input logic [N_BRANCH_RS-1:0]	branch_rs_busy,

	// these signals actually go to the ROB/LDQ/STQ to tell them to
	// allocate an entry
	output logic			alloc_rob_entry,
	output logic			alloc_ldq_entry,
	output logic			alloc_stq_entry,

	output logic [N_ALU_RS-1:0]	alu_rs_route,
	output logic [N_AGU_RS-1:0]	agu_rs_route,
	output logic [N_BRANCH_RS-1:0]	branch_rs_route,

	output logic			stall
	);

	logic rs_type_alu;
	logic rs_type_agu;
	logic rs_type_branch;
	assign rs_type_alu = (instruction_type == 'b00)
		&& !ctl_u_type;	// don't issue a LUI or AUIPC to the ALU unit
	assign rs_type_agu = (instruction_type[1]);	// 'b10 or 'b11
	assign rs_type_branch = (instruction_type == 'b01)
		&& (ctl_jalr || ctl_branch);	// only route to the FU if the instruction actually needs to be executed.
						// JALs do not need to be executed.

	// using lsb fixed priority arbiters to route the instruction to the
	// available reservation station with the lowest index (lowest index
	// is an arbitrary choice I made)

	logic [N_ALU_RS-1:0] alu_rs_arbiter_out;
	logic [N_AGU_RS-1:0] agu_rs_arbiter_out;
	logic [N_BRANCH_RS-1:0] branch_rs_arbiter_out;

	generate
		if (N_ALU_RS > 1) begin
			lsb_fixed_priority_arbiter #(.N(N_ALU_RS)) alu_rs_arbiter (
				.in(~alu_rs_busy),
				.out(alu_rs_arbiter_out)
			);
		end else begin
			assign alu_rs_arbiter_out = ~alu_rs_busy;
		end
	endgenerate

	generate
		if (N_AGU_RS > 1) begin
			lsb_fixed_priority_arbiter #(.N(N_AGU_RS)) agu_rs_arbiter (
				.in(~agu_rs_busy),
				.out(agu_rs_arbiter_out)
			);
		end else begin
			assign agu_rs_arbiter_out = ~agu_rs_busy;
		end
	endgenerate

	generate
		if (N_BRANCH_RS > 1) begin
			lsb_fixed_priority_arbiter #(.N(N_BRANCH_RS)) branch_rs_arbiter (
				.in(~branch_rs_busy),
				.out(branch_rs_arbiter_out)
			);
		end else begin
			assign branch_rs_arbiter_out = ~branch_rs_busy;
		end
	endgenerate

	// we use the valid bit to ensure no reservation stations are enabled
	// if no instruction is actually being issued
	assign alu_rs_route = alu_rs_arbiter_out
		& {N_ALU_RS{rs_type_alu}}
		& {N_ALU_RS{!flush}}
		& {N_ALU_RS{valid}};
	assign branch_rs_route = branch_rs_arbiter_out
		& {N_BRANCH_RS{rs_type_branch}}
		& {N_BRANCH_RS{!flush}}
		& {N_BRANCH_RS{valid}};
	assign agu_rs_route = agu_rs_arbiter_out
		& {N_AGU_RS{rs_type_agu}}
		& {N_AGU_RS{!flush}}
		& {N_AGU_RS{valid}};

	// stall logic

	// these signals determine if we need to stall based on the
	// availability of dependent buffers
	logic stall_rob_full;
	logic stall_ldq_full;
	logic stall_stq_full;

	assign stall_rob_full = ctl_alloc_rob_entry && rob_full;
	assign stall_ldq_full = ctl_alloc_ldq_entry && ldq_full;
	assign stall_stq_full = ctl_alloc_stq_entry && stq_full;

	// these signals determine if we need to stall based on the
	// availability of reservation stations
	logic stall_no_available_alu_rs;
	logic stall_no_available_agu_rs;
	logic stall_no_available_branch_rs;

	assign stall_no_available_alu_rs = &alu_rs_busy && rs_type_alu;
	assign stall_no_available_agu_rs = &agu_rs_busy && rs_type_agu;
	assign stall_no_available_branch_rs = &branch_rs_busy && rs_type_branch;

	// the only reason I'm making this internal signal is that I'm trying
	// VERY HARD to make sure valid is only used at the end of each logic
	// chain
	logic stall_for_any_reason;
	assign stall_for_any_reason = (
		stall_rob_full
		|| stall_ldq_full
		|| stall_stq_full
		|| stall_no_available_alu_rs
		|| stall_no_available_agu_rs
		|| stall_no_available_branch_rs
	);

	// stall if the instruction is valid and any of the reasons to
	// possibly stall are actually met
	assign stall = valid && stall_for_any_reason;

	// we don't allocate an entry if the instruction is being flushed, or
	// isn't being issued for any other reason
	assign alloc_rob_entry = valid && (ctl_alloc_rob_entry && !flush && !stall_for_any_reason);
	assign alloc_ldq_entry = valid && (ctl_alloc_ldq_entry && !flush && !stall_for_any_reason);
	assign alloc_stq_entry = valid && (ctl_alloc_stq_entry && !flush && !stall_for_any_reason);
endmodule

module operand_route #(parameter XLEN=32, parameter ROB_SIZE, parameter ROB_TAG_WIDTH) (
	input control_signal_bus		control_signals,

	// inputs from register file
	input logic [XLEN-1:0]			rs1,
	input logic [ROB_TAG_WIDTH-1:0]		rs1_rob_tag,
	input logic				rs1_rob_tag_valid,
	input logic [XLEN-1:0]			rs2,
	input logic [ROB_TAG_WIDTH-1:0]		rs2_rob_tag,
	input logic				rs2_rob_tag_valid,

	input logic [XLEN-1:0]			pc,
	input logic [XLEN-1:0]			immediate,

	// input logic [ROB_SIZE-1:0]		rob_valid,
	input logic [ROB_SIZE-1:0][XLEN-1:0]	rob_value,
	input logic [ROB_SIZE-1:0]		rob_ready,

	input logic				cdb_valid,
	input wire [XLEN-1:0]			cdb_data,
	input wire [ROB_TAG_WIDTH-1:0]		cdb_rob_tag,

	output logic				q1_valid,
	output logic [ROB_TAG_WIDTH-1:0]	q1,
	output logic [XLEN-1:0]			v1,
	output logic				q2_valid,
	output logic [ROB_TAG_WIDTH-1:0]	q2,
	output logic [XLEN-1:0]			v2
);

	localparam ROB_INDEX_WIDTH = $clog2(ROB_SIZE);
	logic [ROB_INDEX_WIDTH-1:0] rs1_rob_index;
	logic [ROB_INDEX_WIDTH-1:0] rs2_rob_index;
	assign rs1_rob_index = rs1_rob_tag[ROB_INDEX_WIDTH-1:0];
	assign rs2_rob_index = rs2_rob_tag[ROB_INDEX_WIDTH-1:0];

	// LUI and AUIPC are just going to be written stright to the ROB, so they do not have
	// operands routed and are not issued to an execution unit

	// these are the values that will be routed if the value is retrieved
	// from the register file or reorder buffer
	logic				q1_valid_rs1;
	logic [ROB_TAG_WIDTH-1:0]	q1_rs1;
	logic [XLEN-1:0]		v1_rs1;

	logic				q2_valid_rs2;
	logic [ROB_TAG_WIDTH-1:0]	q2_rs2;
	logic [XLEN-1:0]		v2_rs2;

	// we need to monitor the CDB for a tag if the register file has a tag
	// and the ROB cannot yet forward the result
	assign q1_valid_rs1 = rs1_rob_tag_valid && !rob_ready[rs1_rob_index];

	// if we need to use a tag, we simply also need to route the tag
	assign q1_rs1 = q1_valid_rs1 ? rs1_rob_tag : 0;

	// if we don't need to use a tag, we can just route the value
	assign v1_rs1 = (!rs1_rob_tag_valid) ? rs1
		: (rob_ready[rs1_rob_index]) ? rob_value[rs1_rob_index]
		: 0;

	// same logic as rs1 above for forwarding/tagging rs2
	assign q2_valid_rs2 = rs2_rob_tag_valid && !rob_ready[rs2_rob_index];
	assign q2_rs2 = q2_valid_rs2 ? rs2_rob_tag : 0;
	assign v2_rs2 = (!rs2_rob_tag_valid) ? rs2
		: (rob_ready[rs2_rob_index]) ? rob_value[rs2_rob_index]
		: 0;

	// operand 1 routing
	always_comb begin
		unique casez (control_signals.op1_src)
			// LUI or a nop
			2'b00:
			begin
				q1_valid = 0;
				q1 = 0;
				v1 = 0;	// for LUI, this is the actual value
			end

			// JAL or AUIPC
			2'b01:
			begin
				q1_valid = 0;
				q1 = 0;
				v1 = pc;
			end

			// R_TYPE, I_TYPE, B_TYPE, S_TYPE
			2'b1Z:
			begin
				q1_valid = q1_valid_rs1;
				q1 = q1_rs1;
				v1 = v1_rs1;
			end
		endcase

		// If operand 1 has a valid tag, and that tag is present on the CDB, forward the CDB
		// value to the operand
		if (cdb_valid && q1_valid && cdb_rob_tag == q1) begin
			q1_valid = 0;
			q1 = 0;
			v1 = cdb_data;
		end
	end

	always_comb begin
		unique casez (control_signals.op2_src)
			2'b00:
			begin
				q2_valid = 0;
				q2 = 0;
				v2 = 0;
			end

			// I_TYPE, JAL, LUI, AUIPC
			2'b01:
			begin
				q2_valid = 0;
				q2 = 0;
				v2 = immediate;
			end

			// R_TYPE, B_TYPE, S_TYPE
			2'b1Z:
			begin
				q2_valid = q2_valid_rs2;
				q2 = q2_rs2;
				v2 = v2_rs2;
			end
		endcase

		// If operand 2 has a valid tag, and that tag is present on the CDB, forward the CDB
		// value to the operand
		if (cdb_valid && q2_valid && cdb_rob_tag == q2) begin
			q2_valid = 0;
			q2 = 0;
			v2 = cdb_data;
		end
	end
endmodule

// instructions that commit immediately:
// JAL
// JALR
// LUI
// AUIPC
// This module no longer routes stores with ready data to the ROB because the store's data is stored
// in the store_queue.  The store_queue uses q2_valid to evaluate the readiness of the data.  The
// store is considered ready to commit when the ROB sees that entry's tag on the address bus, since
// the store can't commit in-order until all dependent instructions have executed, thus having
// broadcast their data to the CDB which the store_queue will receive it from.
module rob_data_in_route #(parameter XLEN=32) (
	input logic [1:0]	instruction_type,
	// control signals from decode
	input logic		branch,
	input logic		jalr,
	input logic		lui,
	input logic		auipc,

	input logic [XLEN-1:0]	pc,
	input logic		instruction_length,
	input logic [XLEN-1:0]	immediate,

	output logic [XLEN-1:0]	value,
	output logic rob_ready_in
);

	logic [XLEN-1:0]	next_pc;
	assign next_pc = pc + (instruction_length ? XLEN'(4) : XLEN'(2));

	// TODO: analysis on whether this should just be decoded in decode stage
	logic jal;
	assign jal = (instruction_type == 2'b01 && !branch && !jalr);

	// we DON'T want to set ready for JALR and branches, cause these
	// jumps still needs to execute - the data will be stored in the
	// next_instruction field
	assign rob_ready_in = jal || lui || auipc;

	always_comb begin
		if ((instruction_type == 2'b01) && !branch) begin	// JAL or JALR
			value = next_pc;
		end else if (lui) begin
			value = immediate;
		end else if (auipc) begin
			value = pc + immediate;
		end else begin
			value = {XLEN{1'bX}};
		end
	end
endmodule
