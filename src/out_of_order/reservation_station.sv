module reservation_station #(parameter XLEN=32, parameter TAG_WIDTH=32) (
	input logic clk,
	input logic reset,

	input logic enable,
	input logic dispatched_in,	// response from FU that instruction has begun execution

	// using terminology from Hennessy & Patterson book
	// q = tag, v = value
	input logic [TAG_WIDTH-1:0]	q1_in,
	input logic [XLEN-1:0]		v1_in,
	input logic [TAG_WIDTH-1:0]	q2_in,
	input logic [XLEN-1:0]		v2_in,
	input control_signal_bus	control_signals_in,
	input logic [TAG_WIDTH-1:0]	reorder_buffer_tag_in,

	// need to store these to execute branches
	// they should be optimized away during synthesis for the other
	// functional units that aren't using them
	input logic [XLEN-1:0]		pc_plus_four_in,
	input logic [XLEN-1:0]		predicted_next_instruction_in,
	input logic			branch_prediction_in,

	input logic			cdb_valid,
	input wire [TAG_WIDTH-1:0]	cdb_rob_tag,
	input wire [XLEN-1:0]		cdb_data,

	output logic [TAG_WIDTH-1:0]	q1_out,
	output logic [XLEN-1:0]		v1_out,
	output logic [TAG_WIDTH-1:0]	q2_out,
	output logic [XLEN-1:0]		v2_out,
	output control_signal_bus	control_signals_out,
	output logic [TAG_WIDTH-1:0]	reorder_buffer_tag_out,

	output logic [XLEN-1:0]		pc_plus_four_out,
	output logic [XLEN-1:0]		predicted_next_instruction_out,
	output logic			branch_prediction_out,

	output logic			busy,
	output logic			ready_to_execute
	);

	logic dispatched;	// FF to track that the instruction has been accepted by the FU

	// signals that determine whether we need to store the value on the
	// cdb in v1 and/or v2
	logic read_cdb_data_op1;
	logic read_cdb_data_op2;

	// if enable is set, we're gonna be reading the value on qN_in
	// and see if that tag is on the CDB.  else, we're just comparing
	// cdb_rob_tag against what's already in qN_out
	assign read_cdb_data_op1 = ((enable ? q1_in : q1_out) == cdb_rob_tag) && cdb_valid;
	assign read_cdb_data_op2 = ((enable ? q2_in : q2_out) == cdb_rob_tag) && cdb_valid;

	assign ready_to_execute = busy && !dispatched && q1_out == 0 && q2_out == 0;

	always @(posedge clk) begin
		// this is not just the global reset signal, but should also
		// be driven by any other logic that clears the reservation
		// station: i.e. ROB index appears on the CDB or memory
		// address bus
		if (!reset) begin
			q1_out <= 0;
			v1_out <= 0;
			q2_out <= 0;
			v2_out <= 0;
			control_signals_out <= 0;
			reorder_buffer_tag_out <= 0;
			busy <= 0;
			dispatched <= 0;
			pc_plus_four_out <= 0;
			predicted_next_instruction_out <= 0;
			branch_prediction_out <= 0;
		end else begin
			// store 0 if the tag matched the cdb tag, else store
			// input if enable, else retain previous tag
			q1_out <= (read_cdb_data_op1) ? 'b0 : (enable) ? q1_in : q1_out;
			// store cdb data if the tag matches, else store input
			// if enable, else retain previous data value
			v1_out <= (read_cdb_data_op1) ? cdb_data : (enable) ? v1_in : v1_out;

			// same logic as above for the second operand
			q2_out <= (read_cdb_data_op2) ? 'b0 : (enable) ? q2_in : q2_out;
			v2_out <= (read_cdb_data_op2) ? cdb_data : (enable) ? v2_in : v2_out;

			// only update dispatched if it's clear, once it's set
			// we don't want to clear it until the RS triggers
			// a reset condition.
			dispatched <= (!dispatched) ? dispatched_in : dispatched;

			// only update the rest of the signals if enable is set, meaning an
			// instruction is being stored in the reservation stations
			if (enable) begin
				reorder_buffer_tag_out <= reorder_buffer_tag_in;
				control_signals_out <= control_signals_in;
				pc_plus_four_out <= pc_plus_four_in;
				predicted_next_instruction_out <= predicted_next_instruction_in;
				branch_prediction_out <= branch_prediction_in;
				busy <= 1;	// busy because it has stored an instruction!
			end
		end
	end
endmodule

/*
 * This module is just the reset logic for the reservation station.  It's
 * separated from the reservation station because I realized the conditions
 * that I wanted to reset the reservation station for the ALU FU and the
 * AGU are differet: the ALU FU stations reset when they see their ROB tag
 * on the CDB, which is also the source of its operands.  The AGU is also
 * going to read its operands from the CDB, but it needs to reset when it sees
 * its ROB tag on the address bus, so the generic reservation station logic
 * can't be programmed to reset based on the the source of its operands (CDB)
 * - the address isn't sent to the CDB, the value loaded from memory is (and
 *   stores don't put a value on the CDB)
 * - the address FU doesn't need to wait for the load or store to complete:
 *   that's handled by the ROB and load/store queues
 */
module reservation_station_reset #(parameter TAG_WIDTH=32) (
	input logic global_reset,			// ACTIVE LOW
	input logic bus_valid,
	input logic [TAG_WIDTH-1:0] bus_rob_tag,
	input logic [TAG_WIDTH-1:0] rs_rob_tag,
	output logic reservation_station_reset		// ALSO ACTIVE LOW
	);

	assign reservation_station_reset = global_reset
		// have to invert the following reset logic to make it active low
		&& !(bus_valid && bus_rob_tag == rs_rob_tag);
endmodule
