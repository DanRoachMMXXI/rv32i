module test_reservation_station;
	logic clk = 0;
	logic reset = 0;

	logic enable;
	logic dispatched_in;
	logic [31:0] q1_in;
	logic [31:0] v1_in;
	logic [31:0] q2_in;
	logic [31:0] v2_in;
	logic [2:0] alu_op_in;
	logic alu_sign_in;

	logic [31:0] reorder_buffer_tag_in;

	logic cdb_valid;
	logic [31:0] cdb_rob_tag;
	logic [31:0] cdb_data;

	logic [31:0] q1_out;
	logic [31:0] v1_out;
	logic [31:0] q2_out;
	logic [31:0] v2_out;
	logic [2:0] alu_op_out;
	logic alu_sign_out;

	logic [31:0] reorder_buffer_tag_out;
	logic busy;
	logic ready_to_execute;

	reservation_station #(.XLEN(32), .TAG_WIDTH(32)) reservation_station (
		.clk(clk),
		.reset(reset),
		.enable(enable),
		.dispatched_in(dispatched_in),
		.q1_in(q1_in),
		.v1_in(v1_in),
		.q2_in(q2_in),
		.v2_in(v2_in),
		.alu_op_in(alu_op_in),
		.alu_sign_in(alu_sign_in),
		.reorder_buffer_tag_in(reorder_buffer_tag_in),
		.cdb_valid(cdb_valid),
		.cdb_rob_tag(cdb_rob_tag),
		.cdb_data(cdb_data),
		.q1_out(q1_out),
		.v1_out(v1_out),
		.q2_out(q2_out),
		.v2_out(v2_out),
		.alu_op_out(alu_op_out),
		.alu_sign_out(alu_sign_out),
		.reorder_buffer_tag_out(reorder_buffer_tag_out),
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

	initial begin	// test logic
		# 10	// wait for reset
		$display("The reservation station has been reset, all signals should be 0");

		q1_in = 1;
		q2_in = 2;
		alu_op_in = 5;
		alu_sign_in = 0;
		reorder_buffer_tag_in = 7;
		enable = 1;
		# 10	// allow a clock cycle to pass
		$display("enable was set and two non-zero tags were provided.");
		$display("both non-zero tag values should be seen, alu_op = 5");
		$display("reorder_buffer_tag_out should be 7.");
		$display("busy should be set, and ready_to_execute should be clear");
		display_signals();

		enable = 0;
		cdb_rob_tag = 2;
		cdb_data = 4;
		cdb_valid = 0;
		# 10	// allow a clock cycle to pass
		$display("a value is on the CDB, but it is not yet active, so it should");
		$display("not be accepted by the reservation station.  all signals should");
		$display("be the same as the previous.");
		display_signals();

		cdb_valid = 1;
		# 10
		$display("the CDB has been flagged as active, so the cdb_rob_tag should match q2,");
		$display("and v2 should get its value from cdb_data.  Verify that q2_out = 0");
		$display("and v2_out = 4.");
		display_signals();

		cdb_rob_tag = 3;
		# 10;
		$display("the CDB tag does not match q1, no signals should have changed.");
		display_signals();

		cdb_rob_tag = 1;
		cdb_data = 19;
		# 10
		$display("q1 has appeared on the CDB, and the CDB is active.  Verify that");
		$display("q1 = 0, v1 = 19, and ready_to_execute has been set since both");
		$display("operands are present and the instruction has not begun execution");
		display_signals();

		# 10
		$display("dispatched_in has still not been set, as though the FU has not yet");
		$display("accepted the instruction, such as in the case that it accepted an");
		$display("from a different reservation station.  Verify that no signals have");
		$display("changed.");
		display_signals();

		dispatched_in = 1;
		# 10;
		$display("dispatched_in has been set, so the FU has accepted the instruction.");
		$display("verify that ready_to_execute is no longer set.");
		display_signals();

		dispatched_in = 0;
		# 10
		$display("dispatched_in is no longer set, but no output signals should change.");
		display_signals();

		cdb_data = 25;
		cdb_rob_tag = 7;
		# 10
		$display("The value stored in reorder_buffer_tag_out has appeared on the CDB.");
		$display("Verify that all signals in the reservation station have been reset.");
		display_signals();

		cdb_rob_tag = 4;
		cdb_data = 81;
		cdb_valid = 1;
		q1_in = 3;
		q2_in = 4;
		reorder_buffer_tag_in = 19;
		enable = 1;
		# 10
		$display("The reservation station is receiving a new instruction with two non-zero");
		$display("tags.  ONE OF THOSE TAGS (q2) is present on the active CDB.  Verify that");
		$display("q1_out = 3, q2_out = 0, and v2_out = 81, as well as busy = 1,");
		$display("ready_to_execute = 0, and reorder_buffer_tag_out = 19.");
		$display("This test is validating that the reservation station picks up values it");
		$display("needs of the CDB if it's actively present on the CDB at the time the");
		$display("instruction is being stored in the reservation station.");
		display_signals();

		// reset from last test
		enable = 0;
		reset = 0;
		# 10
		reset = 1;

		q1_in = 0;
		v1_in = 9;
		q2_in = 0;
		v2_in = 12;
		reorder_buffer_tag_in = 3;
		enable = 1;
		# 10
		$display("The reservation station has been reset from the previous test.  The");
		$display("reservation station has been provided two ready operands.  Verify that");
		$display("v1 = 9, v2 = 12, the operands' tags are 0, busy = 1, ready_to_execute = 1,");
		$display("and reorder_buffer_tag_out = 3.");
		display_signals();

		// reset from last test
		enable = 0;
		reset = 0;
		# 10
		reset = 1;

		enable = 1;
		q1_in = 10;
		q2_in = 11;
		# 10
		$display("The reservation station has been reset from the previous test.  The");
		$display("reservation station has been provided non-zero tags AND operands.  The");
		$display("defined behavior of the reservation station is that it does not issue declare");
		$display("that the instruction is ready to execute until the tags are 0, so verify that");
		$display("ready_to_execute is clear.");
		display_signals();

		// TODO: for robustness, I could extend the above test to put
		// the values on the CDB and verify they get stored and that
		// the tags are cleared and only then is the instruction ready
		// to execute.  For now, I'm satisfied with this test
		// coverage.
		$finish();
	end

	task display_signals();
		// only displaying station outputs to keep it reasonable to
		// process, the test will state what to look for in the
		// signals to validate them
		$display("---------------------------------------------");
		$display("q1_out: %d, v1_out: %d", q1_out, v1_out);
		$display("q2_out: %d, v2_out: %d", q2_out, v2_out);
		$display("alu_op_out: %d, alu_sign_out: %d", alu_op_out, alu_sign_out);
		$display("reorder_buffer_tag_out: %d", reorder_buffer_tag_out);
		$display("busy: %d, ready_to_execute: %d", busy, ready_to_execute);
		$display("=============================================");
	endtask
endmodule
