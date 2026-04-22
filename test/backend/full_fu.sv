module test_full_fu;
	logic clk = 0;
	logic reset = 0;

	// test signals
	logic enable;
	logic [31:0] q1_in;
	logic [31:0] v1_in;
	logic [31:0] q2_in;
	logic [31:0] v2_in;
	control_signal_bus control_signal_bus_in;
	logic [31:0] reorder_buffer_tag_in;
	logic cdb_permit;	// this signal would come from an arbitration system

	logic rs_reset;

	logic cdb_valid;
	wire [31:0] cdb_rob_tag;
	wire [31:0] cdb_data;

	logic tb_drive_cdb;	// the testbench drives the CDB, as though it were given access to do so by the CDB arbiter
	logic [31:0] tb_cdb_data;
	logic [31:0] tb_cdb_rob_tag;

	logic [31:0] q1_out;
	logic [31:0] v1_out;
	logic [31:0] q2_out;
	logic [31:0] v2_out;
	control_signal_bus control_signal_bus_out;

	logic [31:0] reorder_buffer_tag_out;
	logic busy;
	logic ready_to_execute;

	logic [31:0] fu_result;
	logic fu_accept;
	logic fu_write_to_buf;

	logic output_buf_not_empty;

	assign cdb_data = tb_drive_cdb ? tb_cdb_data : 'bZ;
	assign cdb_rob_tag = tb_drive_cdb ? tb_cdb_rob_tag : 'bZ;

	reservation_station #(.XLEN(32), .TAG_WIDTH(32)) reservation_station (
		.clk(clk),
		.reset(rs_reset),
		.enable(enable),
		.dispatched_in(fu_accept),
		.q1_in(q1_in),
		.v1_in(v1_in),
		.q2_in(q2_in),
		.v2_in(v2_in),
		.control_signal_bus_in(control_signal_bus_in),
		.reorder_buffer_tag_in(reorder_buffer_tag_in),
		.pc_plus_four_in(),
		.predicted_next_instruction_in(),
		.branch_prediction_in(),
		.cdb_valid(cdb_valid),
		.cdb_rob_tag(cdb_rob_tag),
		.cdb_data(cdb_data),
		.q1_out(q1_out),
		.v1_out(v1_out),
		.q2_out(q2_out),
		.v2_out(v2_out),
		.control_signal_bus_out(control_signal_bus_out),
		.reorder_buffer_tag_out(reorder_buffer_tag_out),
		.pc_plus_four_out(),
		.predicted_next_instruction_out(),
		.branch_prediction_out(),
		.busy(busy),
		.ready_to_execute(ready_to_execute)
	);

	reservation_station_reset #(.TAG_WIDTH(32)) reservation_station_reset (
		.global_reset(reset),
		.bus_valid(cdb_valid),
		.bus_rob_tag(cdb_rob_tag),
		.rs_rob_tag(reorder_buffer_tag_out),
		.reservation_station_reset(rs_reset)
	);

	alu_functional_unit #(.XLEN(32)) fu (
		.a(v1_out),
		.b(v2_out),
		.op(control_signal_bus_out.funct3),
		.sign(control_signal_bus_out.sign),
		.result(fu_result),
		.ready_to_execute(ready_to_execute),
		.accept(fu_accept),
		.write_to_buffer(fu_write_to_buf)
	);

	functional_unit_output_buffer #(.XLEN(32), .TAG_WIDTH(32)) output_buf (
		.clk(clk),
		.reset(reset),
		.value(fu_result),
		.tag(reorder_buffer_tag_out),
		.write_en(fu_write_to_buf),
		.not_empty(output_buf_not_empty),
		.data_bus_permit(cdb_permit),
		.data_bus_data(cdb_data),
		.data_bus_tag(cdb_rob_tag),
		.read_from(),
		.write_to()
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

		enable = 1;
		q1_in = 10;
		q2_in = 12;
		control_signal_bus_in.funct3 = 0;		// addition
		control_signal_bus_in.sign = 0;
		reorder_buffer_tag_in = 19;
		# 10
		// An instruction has been issued to the reservation station.
		// Neither operand is currently present.  Verify that the
		// instruction has not been issued, the FU has not accepted,
		// and nothing is in the output buffer.
		assert(q1_out == 10);
		assert(v1_out == 0);
		assert(q2_out == 12);
		assert(v2_out == 0);
		assert(reorder_buffer_tag_out == 19);

		assert(busy == 1);
		assert(ready_to_execute == 0);
		assert(fu_accept == 0);
		assert(output_buf_not_empty == 0);

		enable = 0;
		tb_drive_cdb = 1;
		cdb_valid = 1;
		tb_cdb_data = 24;
		tb_cdb_rob_tag = 10;
		# 10
		// Operand 1 was present on the CDB, verify it is in the
		// reservation station, the instruction has not been issued,
		// and that the output buffer is empty
		assert(q1_out == 0);
		assert(v1_out == 24);
		assert(q2_out == 12);
		assert(v2_out == 0);

		assert(busy == 1);
		assert(ready_to_execute == 0);
		assert(fu_accept == 0);
		assert(output_buf_not_empty == 0);

		tb_cdb_data = 17;
		tb_cdb_rob_tag = 12;
		# 10
		$display("Operand 2 was present on the CDB, verify it is in the reservation");
		$display("station and that ready_to_execute is set.  Since the FU is combinational,");
		$display("the result should be computed and write_to_buffer should be set.");
		$display("Also, the FU should set accept, and this should cause the reservation");
		$display("station to clear ready_to_execute next cycle.");
		assert(q1_out == 0);
		assert(v1_out == 24);
		assert(q2_out == 0);
		assert(v2_out == 17);

		assert(busy == 1);
		assert(ready_to_execute == 1);
		assert(fu_accept == 1);
		assert(fu_write_to_buf == 1);
		// the value will write to the buffer on the next clock edge
		assert(output_buf_not_empty == 0);

		// stop driving the CDB from the testbench
		tb_drive_cdb = 0;
		cdb_valid = 0;

		# 10
		// One clock cycle has passed.
		// No signals were changed beyond the testbench yielding
		// control of the CDB. Verify that the result from the
		// previous clock cycle has been stored in the output buffer,
		// and that the output buffer has not_empty set.
		assert(busy == 1);
		assert(ready_to_execute == 0);	// should be 0 because the RS stores that it has already been dispatched
		assert(fu_accept == 0);
		assert(fu_write_to_buf == 0);
		assert(output_buf_not_empty == 1);

		cdb_permit = 1;	// permit the buffer to write to the CDB
		cdb_valid = 1;	// the arbiter would set this
		# 2
		// A full clock cycle has NOT passed since the last signals
		// were printed. The output buffer has been permitted to write
		// to the CDB, verify that the result is present on the CDB,
		// as well as the reorder buffer tag (19)
		assert(cdb_data == 41);
		assert(cdb_rob_tag == 19);

		# 8
		// The rest of the clock cycle has passed.  Since the ROB tag
		// appeared on the CDB while the CDB was designated as active,
		// verify that the reservation station has had its signals
		// reset.
		assert(q1_out == 0);
		assert(v1_out == 0);
		assert(q2_out == 0);
		assert(v2_out == 0);
		assert(reorder_buffer_tag_out == 0);

		assert(busy == 0);
		assert(ready_to_execute == 0);
		assert(fu_accept == 0);
		assert(output_buf_not_empty == 0);

		$display("All assertions passed.");
		$finish();
	end
endmodule
