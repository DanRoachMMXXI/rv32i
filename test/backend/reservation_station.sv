module test_reservation_station;
	localparam XLEN=32;
	localparam ROB_TAG_WIDTH=32;

	logic clk = 0;
	logic reset = 0;

	logic				enable;
	logic				dispatched_in;
	logic				q1_valid_in;
	logic [ROB_TAG_WIDTH-1:0]	q1_in;
	logic [XLEN-1:0]		v1_in;
	logic				q2_valid_in;
	logic [ROB_TAG_WIDTH-1:0]	q2_in;
	logic [XLEN-1:0]		v2_in;
	control_signal_bus		control_signals_in;

	logic [ROB_TAG_WIDTH-1:0]	rob_tag_in;

	logic				cdb_valid;
	logic [ROB_TAG_WIDTH-1:0]	cdb_rob_tag;
	logic [XLEN-1:0]		cdb_data;

	logic				q1_valid_out;
	logic [ROB_TAG_WIDTH-1:0]	q1_out;
	logic [XLEN-1:0]		v1_out;
	logic				q2_valid_out;
	logic [ROB_TAG_WIDTH-1:0]	q2_out;
	logic [XLEN-1:0]		v2_out;
	control_signal_bus		control_signals_out;

	logic [ROB_TAG_WIDTH-1:0]	rob_tag_out;
	logic				busy;
	logic				ready_to_execute;

	reservation_station #(.XLEN(32), .TAG_WIDTH(32)) reservation_station (
		.clk(clk),
		.reset(reset),

		.enable(enable),
		.dispatched_in(dispatched_in),

		.q1_valid_in(q1_valid_in),
		.q1_in(q1_in),
		.v1_in(v1_in),
		.q2_valid_in(q2_valid_in),
		.q2_in(q2_in),
		.v2_in(v2_in),
		.control_signals_in(control_signals_in),
		.rob_tag_in(rob_tag_in),

		.pc_plus_four_in(),
		.predicted_next_instruction_in(),
		.branch_prediction_in(),

		.cdb_valid(cdb_valid),
		.cdb_rob_tag(cdb_rob_tag),
		.cdb_data(cdb_data),

		.q1_valid_out(q1_valid_out),
		.q1_out(q1_out),
		.v1_out(v1_out),
		.q2_valid_out(q2_valid_out),
		.q2_out(q2_out),
		.v2_out(v2_out),
		.control_signals_out(control_signals_out),

		.pc_plus_four_out(),
		.predicted_next_instruction_out(),
		.branch_prediction_out(),
		
		.rob_tag_out(rob_tag_out),
		.busy(busy),
		.ready_to_execute(ready_to_execute)
		);

	// disable the active low reset after the first clock cycle
	initial begin
		#10 reset = 1;
	end

	always begin
		#5 clk = ~clk;
	end

	// TODO: rewrite test to use the control_signals structure
	// TODO: rewrite the test to use assertions.

	initial begin	// test logic
		# 10	// wait for reset

		q1_valid_in = 1;
		q1_in = 1;
		q2_valid_in = 1;
		q2_in = 2;
		control_signals_in.funct3 = 5;
		control_signals_in.sign = 0;
		rob_tag_in = 7;
		enable = 1;
		# 10	// allow a clock cycle to pass
		assert(busy == 1);
		assert(q1_valid_out == 1);
		assert(q1_out == 1);
		assert(q2_valid_out == 1);
		assert(q2_out == 2);
		assert(control_signals_out.funct3 == 5);
		assert(control_signals_out.sign == 0);
		assert(rob_tag_out == 7);
		assert(ready_to_execute == 0);

		enable = 0;
		cdb_rob_tag = 2;
		cdb_data = 4;
		cdb_valid = 0;
		# 10	// allow a clock cycle to pass
		assert(busy == 1);
		assert(q1_valid_out == 1);
		assert(q1_out == 1);
		assert(q2_valid_out == 1);
		assert(q2_out == 2);
		assert(control_signals_out.funct3 == 5);
		assert(control_signals_out.sign == 0);
		assert(rob_tag_out == 7);
		assert(ready_to_execute == 0);

		cdb_valid = 1;
		# 10
		// the CDB has been flagged as active, so the cdb_rob_tag
		// should match q2, and v2 should get its value from cdb_data.
		// Verify that q2_out = 0 and v2_out = 4.
		assert(q2_valid_out == 0);
		assert(q2_out == 0);
		assert(v2_out == 4);
		// verify the other signals are the same
		assert(q1_valid_out == 1);
		assert(q1_out == 1);

		cdb_rob_tag = 3;
		# 10;
		// the CDB tag does not match q1, no signals should have
		// changed. verify the other signals are the same
		assert(q1_valid_out == 1);
		assert(q1_out == 1);
		assert(ready_to_execute == 0);

		cdb_rob_tag = 1;
		cdb_data = 19;
		# 10
		// q1 has appeared on the CDB, and the CDB is active.  Verify
		// that q1 = 0, v1 = 19, and ready_to_execute has been set
		// since both operands are present and the instruction has not
		// begun execution
		assert(busy == 1);
		assert(q1_valid_out == 0);
		assert(q1_out == 0);
		assert(v1_out == 19);
		assert(q2_valid_out == 0);
		assert(q2_out == 0);
		assert(v2_out == 4);
		assert(ready_to_execute == 1);

		# 10
		// dispatched_in has still not been set, as though the FU has
		// not yet accepted the instruction, such as in the case that
		// it accepted an from a different reservation station.
		// Verify that no signals have changed.
		assert(busy == 1);
		assert(q1_valid_out == 0);
		assert(q1_out == 0);
		assert(v1_out == 19);
		assert(q2_valid_out == 0);
		assert(q2_out == 0);
		assert(v2_out == 4);
		assert(ready_to_execute == 1);

		dispatched_in = 1;
		# 10;
		// dispatched_in has been set, so the FU has accepted the
		// instruction. verify that ready_to_execute is no longer set.
		assert(busy == 1);
		assert(ready_to_execute == 0);

		dispatched_in = 0;
		# 10
		// dispatched_in is no longer set, but no output signals
		// should change.
		assert(busy == 1);
		assert(ready_to_execute == 0);

		cdb_data = 25;
		cdb_rob_tag = 7;
		# 10
		// The value stored in rob_tag_out has appeared on the CDB.
		// Verify that all signals in the reservation station have
		// been reset.
		assert(busy == 0);
		assert(ready_to_execute == 0);
		assert(q1_valid_out == 0);
		assert(q2_valid_out == 0);
		assert(q1_out == 0);
		assert(q2_out == 0);
		assert(v1_out == 0);
		assert(v2_out == 0);

		cdb_rob_tag = 4;
		cdb_data = 81;
		cdb_valid = 1;
		q1_valid_in = 1;
		q1_in = 3;
		q2_valid_in = 1;
		q2_in = 4;
		rob_tag_in = 19;
		enable = 1;
		# 10
		// The reservation station is receiving a new instruction with
		// two non-zero tags.  ONE OF THOSE TAGS (q2) is present on
		// the active CDB.  Verify that q1_out = 3, q2_out = 0, and
		// v2_out = 81, as well as busy = 1, ready_to_execute = 0, and
		// rob_tag_out = 19. This test is validating that the
		// reservation station picks up values it needs of the CDB if
		// it's actively present on the CDB at the time the
		// instruction is being stored in the reservation station.
		assert(busy == 1);
		assert(q1_valid_out == 1);
		assert(q1_out == 3);
		assert(q2_valid_out == 0);
		assert(q2_out == 0);
		assert(v2_out == 81);
		assert(ready_to_execute == 0);
		assert(rob_tag_out == 19);

		// reset from last test
		enable = 0;
		reset = 0;
		# 10
		reset = 1;

		q1_valid_in = 0;
		q1_in = 0;
		v1_in = 9;
		q2_valid_in = 0;
		q2_in = 0;
		v2_in = 12;
		rob_tag_in = 3;
		enable = 1;
		# 10
		// The reservation station has been reset from the previous
		// test.  The reservation station has been provided two ready
		// operands.  Verify that v1 = 9, v2 = 12, the operands' tags
		// are 0, busy = 1, ready_to_execute = 1, and rob_tag_out = 3.
		assert(busy == 1);
		assert(q1_valid_out == 0);
		assert(q1_out == 0);
		assert(v1_out == 9);
		assert(q2_valid_out == 0);
		assert(q2_out == 0);
		assert(v2_out == 12);
		assert(ready_to_execute == 1);
		assert(rob_tag_out == 3);

		// reset from last test
		enable = 0;
		reset = 0;

		// TODO: for robustness, I could extend the above test to put
		// the values on the CDB and verify they get stored and that
		// the tags are cleared and only then is the instruction ready
		// to execute.  For now, I'm satisfied with this test
		// coverage.
		$display("All assertions passed.");
		$finish();
	end
endmodule
