/*
 * TODO: figure out rs1 source for JALR target predictions
 * - when we pop off the RAS, we absolutely use that value
 * - when we aren't popping off the RAS, what do we use as a source?  I think
 *   there could be an argument for caching or forwarding LUI and AUIPC values
 *   from recent instructions (say the instruction just before the prediction)
 *   and using that when we see that rs1_index for the JALR is the same as the
 *   rd_index for the LUI or AUIPC.
 *   - I think this is a good cook
 *   - Talking with ChatGPT, it recommends "folding" the two instructions, not
 *   necessarily caching or forwarding.  Front end logic is specifically
 *   looking for an AUIPC/LUI followed by a JALR with a matching source
 *   register.  If the JALR rd overwrites the AUIPC/LUI rd, then the AUIPC/LUI
 *   does not need to be written to the ROB/RF, as the architectural state
 *   change is not visible.  This seems to be folding.
 *     - Supposedly "folding" is a term used for front-end optimization
 *     without computing the value in execution, and forwarding is using the
 *     computed value from execution before it writes back.  Since this is
 *     a front-end optimization, we call it folding.
 * - when neither of the above cases are viable, we use a branch target buffer
 *   or an indirect target predictor
 *   - this is a PC indexed data structure
 * - of note: ChatGPT mentions using the BTB/ITP for branches as well, as it
 *   saves us the one or more cycles it takes to decode the instruction where
 *   we identify it's a branch and construct the immediate value, add the
 *   immediate to PC, compute our branch prediction and update PC.  all these
 *   cycles are unavoidable stalls (unless we just load PC+4 in the meantime),
 *   but the BTB/ITP should provide greater accuracy
 *   - this is an optimization for WAY later tho, once the out-of-order design
 *   is proven to be working without it.
 */
module cpu #(
	parameter XLEN=32,
	parameter ROB_SIZE,
	parameter LDQ_SIZE,
	parameter STQ_SIZE,
	parameter N_ALU_RS,
	parameter N_AGU_RS,
	parameter N_BRANCH_RS) (
);
	instruction_decode #(.XLEN(XLEN)) instruction_decode (
		.instruction(),
		.immedate(),
		.control_signals()
	);

	instruction_route #(.N_ALU_RS(N_ALU_RS), .N_AGU_RS(N_AGU_RS), .N_BRANCH_RS(N_BRANCH_RS)) instruction_route (
		.instruction_type(),
		.alu_rs_busy(),
		.agu_rs_busy(),
		.branch_rs_busy(),
		.alu_rs_route(),
		.agu_rs_route(),
		.branch_rs_route(),
		.stall()
	);

	register_file #(.XLEN(XLEN)) register_file (
		.clk(clk),
		.reset(reset),
		.rs1_index(),
		.rs2_index(),
		.rd_index(),
		.rd(),
		.write_en(),

		.rs1(),
		.rs2()
	);
	
	// Generate the ALU execution pipeline N_ALU_RS times
	genvar alu_genvar;
	generate
		for (alu_genvar = 0; alu_genvar < N_ALU_RS; alu_genvar = alu_genvar + 1) begin
			reservation_station #(.XLEN(XLEN), .TAG_WIDTH($clog2(ROB_SIZE))) alu_rs (
				.clk(clk),
				.reset(),	// remember to use the reset module to reset the rs
				.q1_in(),
				.v1_in(),
				.q2_in(),
				.v2_in(),
				.control_signals_in(),
				.reorder_buffer_tag_in(),
				.pc_plus_four_in(),
				.predicted_next_instruction_in(),
				.branch_prediction_in(),
				.cdb_valid(),
				.cdb_rob_tag(),
				.cdb_data(),
				.q1_out(),
				.v1_out(),
				.q2_out(),
				.v2_out(),
				.control_signals_out(),
				.reorder_buffer_tag_out(),
				.pc_plus_four_out(),
				.predicted_next_instruction_out(),
				.branch_prediction_out(),
				.busy(),
				.ready_to_execute()
			);

			reservation_station_reset #(.TAG_WIDTH($clog2(ROB_SIZE))) rs_reset (
				.global_reset(reset),
				.bus_valid(),
				.bus_rob_tag(),
				.rs_rob_tag(),
				.reservation_station_reset()	// this goes into the RS ^
			);

			alu_functional_unit #(.XLEN(XLEN)) alu_functional_unit (
				.a(),
				.b(),
				.op(),
				.sign(),
				.result(),
				.ready_to_execute(),
				.accept(),
				.write_to_buffer()
			);

			functional_unit_output_buffer #(.XLEN(XLEN), .TAG_WIDTH($clog2(ROB_SIZE))) alu_output_buf (
				.clk(),
				.reset(),
				.value(),
				.tag(),
				.write_en(),
				.not_empty(),
				.data_bus_permit(),
				.data_bus_data(),
				.data_bus_tag(),
				.read_from(),
				.write_to()
			);
		end
	endgenerate

	// Generate the AGU execution pipeline N_AGU_RS times, which will
	// broadcast results to the Load/Store Unit
	genvar agu_genvar;
	generate
		for (agu_genvar = 0; agu_genvar < N_AGU_RS; agu_genvar = agu_genvar + 1) begin
			reservation_station #(.XLEN(XLEN), .TAG_WIDTH($clog2(ROB_SIZE))) agu_rs (
				.clk(clk),
				.reset(),	// remember to use the reset module to reset the rs
				.q1_in(),
				.v1_in(),
				.q2_in(),
				.v2_in(),
				.control_signals_in(),
				.reorder_buffer_tag_in(),
				.pc_plus_four_in(),
				.predicted_next_instruction_in(),
				.branch_prediction_in(),
				.cdb_valid(),
				.cdb_rob_tag(),
				.cdb_data(),
				.q1_out(),
				.v1_out(),
				.q2_out(),
				.v2_out(),
				.control_signals_out(),
				.reorder_buffer_tag_out(),
				.pc_plus_four_out(),
				.predicted_next_instruction_out(),
				.branch_prediction_out(),
				.busy(),
				.ready_to_execute()
			);

			reservation_station_reset #(.TAG_WIDTH($clog2(ROB_SIZE))) rs_reset (
				.global_reset(reset),
				.bus_valid(),
				.bus_rob_tag(),
				.rs_rob_tag(),
				.reservation_station_reset()	// this goes into the RS ^
			);

			memory_address_functional_unit #(.XLEN(XLEN)) memory_address_functional_unit (
				.base(),
				.offset(),
				.result(),
				.ready_to_execute(),
				.accept(),
				.write_to_buffer()
			);

			functional_unit_output_buffer #(.XLEN(XLEN), .TAG_WIDTH($clog2(ROB_SIZE))) agu_output_buf (
				.clk(),
				.reset(),
				.value(),
				.tag(),
				.write_en(),
				.not_empty(),
				.data_bus_permit(),
				.data_bus_data(),
				.data_bus_tag(),
				.read_from(),
				.write_to()
			);
		end
	endgenerate
	
	// Generate the branch execution pipeline N_BRANCH_RS times
	genvar branch_genvar;
	generate
		for (branch_genvar = 0; branch_genvar < N_BRANCH_RS; branch_genvar = branch_genvar + 1) begin
			reservation_station #(.XLEN(XLEN), .TAG_WIDTH($clog2(ROB_SIZE))) branch_rs (
				.clk(clk),
				.reset(),	// remember to use the reset module to reset the rs
				.q1_in(),
				.v1_in(),
				.q2_in(),
				.v2_in(),
				.control_signals_in(),
				.reorder_buffer_tag_in(),
				.pc_plus_four_in(),
				.predicted_next_instruction_in(),
				.branch_prediction_in(),
				.cdb_valid(),
				.cdb_rob_tag(),
				.cdb_data(),
				.q1_out(),
				.v1_out(),
				.q2_out(),
				.v2_out(),
				.control_signals_out(),
				.reorder_buffer_tag_out(),
				.pc_plus_four_out(),
				.predicted_next_instruction_out(),
				.branch_prediction_out(),
				.busy(),
				.ready_to_execute()
			);

			reservation_station_reset #(.TAG_WIDTH($clog2(ROB_SIZE))) rs_reset (
				.global_reset(reset),
				.bus_valid(),
				.bus_rob_tag(),
				.rs_rob_tag(),
				.reservation_station_reset()	// this goes into the RS ^
			);

			branch_functional_unit #(.XLEN(XLEN)) branch_functional_unit (
				.v1(),
				.v2(),
				.pc_plus_four(),
				.predicted_next_instruction(),
				.jump(),
				.branch(),
				.branch_if_zero(),
				.branch_prediction(),
				.next_instruction(),
				.branch_mispredicted(),
				.ready_to_execute(),
				.accept(),
				.write_to_buffer()
			);

			functional_unit_output_buffer #(.XLEN(XLEN), .TAG_WIDTH($clog2(ROB_SIZE))) branch_output_buf (
				.clk(),
				.reset(),
				.value(),
				.tag(),
				.write_en(),
				.not_empty(),
				.data_bus_permit(),
				.data_bus_data(),
				.data_bus_tag(),
				.read_from(),
				.write_to()
			);
		end
	endgenerate

	reorder_buffer #(.XLEN(XLEN), .BUF_SIZE(ROB_SIZE), .TAG_WIDTH($clog2(ROB_SIZE))) reorder_buffer (
		.clk(clk),
		.reset(reset),
		.input_en(),
		.instruction_type_in(),
		.destination_in(),
		.value_in(),
		.data_ready_in(),
		.pc_in(),
		.cdb_valid(),
		.cdb_data(),
		.cdb_rob_tag(),
		.cdb_exception(),
		.branch_mispredict(),
		.agu_address_valid(),
		.agu_address_data(),
		.agu_address_rob_tag(),
		.flush(),
		.new_tail(),
		.rob_valid(),
		.rob_instruction_type(),
		.rob_address_valid(),
		.rob_destination(),
		.rob_value(),
		.rob_data_ready(),
		.rob_branch_mispredict(),
		.rob_exception(),
		.rob_next_instruction(),
		.head(),
		.tail(),
		.commit(),
		.full()
	);

	// TODO buffer_flusher once it's finalized, it's just got too many
	// TODOs to warrant writing it out now.

	cdb_arbiter #(.N(N_ALU_RS + N_BRANCH_RS)) cdb_arbiter (
		.request(),
		.grant(),
		.cdb_active()
	);

	cdb_arbiter #(.N(N_AGU_RS)) agu_bus_arbiter (
		.request(),
		.grant(),
		.cdb_active()
	);
endmodule
