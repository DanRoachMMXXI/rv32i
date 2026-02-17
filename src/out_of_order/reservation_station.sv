module reservation_station #(parameter XLEN=32, parameter ROB_TAG_WIDTH) (
	input logic clk,
	input logic reset,

	input logic			enable,
	input logic			dispatched_in,	// response from FU that instruction has begun execution

	// using terminology from Hennessy & Patterson book
	// q = tag, v = value
	// using a valid bit to indicate whether the operand needs to monitor
	// the CDB for the tag
	input logic			q1_valid_in,
	input logic [ROB_TAG_WIDTH-1:0]	q1_in,
	input logic [XLEN-1:0]		v1_in,
	input logic			q2_valid_in,
	input logic [ROB_TAG_WIDTH-1:0]	q2_in,
	input logic [XLEN-1:0]		v2_in,
	input control_signal_bus	control_signals_in,
	input logic [ROB_TAG_WIDTH-1:0]	rob_tag_in,

	// need to store these to execute branches
	// they should be optimized away during synthesis for the other
	// functional units that aren't using them, so for reservation
	// stations connected to other functional units, just be sure to wire
	// these inputs to 0 and leave the corresponding outputs disconnected.
	// TODO: ChatGPT mentioned in a different context storing the PC of
	// the instruction in the ROB as a dedicated field.  That's kinda what
	// next_instruction is serving as rn, but branch mispredicts overwrite
	// it.  I wanna look at storing the PC in the ROB, and possibly
	// removing it from the reservation stations.
	// In this implementation, the PC in the reservation station should be
	// optimized away for all non-branch reservation stations since it
	// won't be connected to anything
	input logic [XLEN-1:0]			pc_in,
	input logic [XLEN-1:0]			immediate_in,
	input logic [XLEN-1:0]			predicted_next_instruction_in,
	input logic				branch_prediction_in,

	input logic				cdb_valid,
	input wire [ROB_TAG_WIDTH-1:0]		cdb_rob_tag,
	input wire [XLEN-1:0]			cdb_data,

	output logic [XLEN-1:0]			v1_out,
	output logic [XLEN-1:0]			v2_out,
	output control_signal_bus		control_signals_out,
	output logic [ROB_TAG_WIDTH-1:0]	rob_tag_out,

	output logic [XLEN-1:0]			pc_out,
	output logic [XLEN-1:0]			immediate_out,
	output logic [XLEN-1:0]			predicted_next_instruction_out,
	output logic				branch_prediction_out,

	output logic				busy,
	output logic				ready_to_execute,

	// debug outputs
	output logic				q1_valid,
	output logic [ROB_TAG_WIDTH-1:0]	q1,
	output logic				q2_valid,
	output logic [ROB_TAG_WIDTH-1:0]	q2
	);

	// logic				q1_valid;
	// logic [ROB_TAG_WIDTH-1:0]	q1;
	// logic				q2_valid;
	// logic [ROB_TAG_WIDTH-1:0]	q2;

	logic dispatched;	// FF to track that the instruction has been accepted by the FU

	// signals that determine whether we need to store the value on the
	// cdb in v1 and/or v2

	assign ready_to_execute = busy && !dispatched && q1_valid == 0 && q2_valid == 0;

	always @(posedge clk) begin
		// this is not just the global reset signal, but should also
		// be driven by any other logic that clears the reservation
		// station: i.e. ROB index appears on the CDB or memory
		// address bus
		if (!reset) begin
			q1_valid <= 0;
			q1 <= 0;
			v1_out <= 0;
			q2_valid <= 0;
			q2 <= 0;
			v2_out <= 0;
			control_signals_out <= 0;
			rob_tag_out <= 0;
			busy <= 0;
			dispatched <= 0;
			pc_out <= 0;
			immediate_out <= 0;
			predicted_next_instruction_out <= 0;
			branch_prediction_out <= 0;
		end else begin
			// only update dispatched if it's clear, once it's set
			// we don't want to clear it until the RS triggers
			// a reset condition.
			if (!dispatched)
				dispatched <= dispatched_in;

			// only update the rest of the signals if enable is set, meaning an
			// instruction is being stored in the reservation stations
			if (enable) begin
				q1_valid <= q1_valid_in;
				q1 <= q1_in;
				v1_out <= v1_in;

				q2_valid <= q2_valid_in;
				q2 <= q2_in;
				v2_out <= v2_in;

				rob_tag_out <= rob_tag_in;
				control_signals_out <= control_signals_in;
				pc_out <= pc_in;
				immediate_out <= immediate_in;
				predicted_next_instruction_out <= predicted_next_instruction_in;
				branch_prediction_out <= branch_prediction_in;
				busy <= 1;	// busy because it has stored an instruction!
				dispatched <= 0;
			end

			// it shouldn't matter that enable overwrites this, as enable never should
			// be set when the RS has valid contents, but just noting that if enable is
			// set, this is written to store the inputs and ignore whether the CDB
			// matches the old values
			else if (cdb_valid) begin
				if (q1_valid && q1 == cdb_rob_tag) begin
					q1_valid <= 1'b0;
					q1 <= 'b0;
					v1_out <= cdb_data;
				end

				if (q2_valid && q2 == cdb_rob_tag) begin
					q2_valid <= 1'b0;
					q2 <= 'b0;
					v2_out <= cdb_data;
				end
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
 * - TODO: take in flush signal from ROB and reset the RS if flush[rs_rob_tag]
 *   is set.
 */
module reservation_station_reset #(parameter ROB_TAG_WIDTH=32) (
	input logic global_reset,			// ACTIVE LOW
	input logic bus_valid,
	input logic [ROB_TAG_WIDTH-1:0] bus_rob_tag,
	input logic [ROB_TAG_WIDTH-1:0] rs_rob_tag,
	output logic reservation_station_reset		// ALSO ACTIVE LOW
	);

	assign reservation_station_reset = global_reset
		// have to invert the following reset logic to make it active low
		&& !(bus_valid && bus_rob_tag == rs_rob_tag);
endmodule
