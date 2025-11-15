module test_full_fu;
	logic clk = 0;
	logic reset = 0;

	// test signals
	logic enable;
	logic [31:0] q1_in;
	logic [31:0] v1_in;
	logic [31:0] q2_in;
	logic [31:0] v2_in;
	logic [2:0] alu_op_in;
	logic alu_sign_in;
	logic [31:0] reorder_buffer_tag_in;
	logic cdb_permit;	// this signal would come from an arbitration system

	logic cdb_active;
	wire [31:0] cdb_tag;
	wire [31:0] cdb_data;

	logic tb_drive_cdb;	// the testbench drives the CDB, as though it were given access to do so by the CDB arbiter
	logic [31:0] tb_cdb_data;
	logic [31:0] tb_cdb_tag;

	logic [31:0] q1_out;
	logic [31:0] v1_out;
	logic [31:0] q2_out;
	logic [31:0] v2_out;
	logic [2:0] alu_op_out;
	logic alu_sign_out;

	logic [31:0] reorder_buffer_tag_out;
	logic busy;
	logic ready_to_execute;

	logic [31:0] fu_result;
	logic fu_accept;
	logic fu_write_to_buf;

	logic output_buf_not_empty;

	assign cdb_data = tb_drive_cdb ? tb_cdb_data : 'bZ;
	assign cdb_tag = tb_drive_cdb ? tb_cdb_tag : 'bZ;

	reservation_station #(.XLEN(32), .TAG_WIDTH(32)) reservation_station (
		.clk(clk),
		.reset(reset),
		.enable(enable),
		.dispatched_in(fu_accept),
		.q1_in(q1_in),
		.v1_in(v1_in),
		.q2_in(q2_in),
		.v2_in(v2_in),
		.alu_op_in(alu_op_in),
		.alu_sign_in(alu_sign_in),
		.reorder_buffer_tag_in(reorder_buffer_tag_in),
		.cdb_active(cdb_active),
		.cdb_tag(cdb_tag),
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

	alu_functional_unit #(.XLEN(32)) fu (
		.a(v1_out),
		.b(v2_out),
		.op(alu_op_out),
		.sign(alu_sign_out),
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
		.cdb_permit(cdb_permit),
		.cdb_data(cdb_data),
		.cdb_tag(cdb_tag),
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
		alu_op_in = 0;		// addition
		alu_sign_in = 0;
		reorder_buffer_tag_in = 19;
		# 10
		$display("An instruction has been issued to the reservation station.");
		$display("Neither operand is currently present.  Verify that the instruction");
		$display("has not been issued, the FU has not accepted, and nothing is in the");
		$display("output buffer.");
		display_signals();

		enable = 0;
		tb_drive_cdb = 1;
		cdb_active = 1;
		tb_cdb_data = 24;
		tb_cdb_tag = 10;
		# 10
		$display("Operand 1 was present on the CDB, verify it is in the reservation");
		$display("station, the instruction has not been issued, and that the output");
		$display("buffer is empty");
		display_signals();

		tb_cdb_data = 17;
		tb_cdb_tag = 12;
		# 10
		$display("Operand 2 was present on the CDB, verify it is in the reservation");
		$display("station and that ready_to_execute is set.  Since the FU is combinational,");
		$display("the result should be computed and write_to_buffer should be set.");
		$display("Also, the FU should set accept, and this should cause the reservation");
		$display("station to clear ready_to_execute next cycle.");
		display_signals();

		// stop driving the CDB from the testbench
		tb_drive_cdb = 0;
		cdb_active = 0;

		# 10
		$display("One clock cycle has passed.");
		$display("No signals were changed beyond the testbench yielding control of the CDB.");
		$display("Verify that the result from the previous clock cycle has been stored in the");
		$display("output buffer, and that the output buffer has not_empty set.");
		display_signals();

		cdb_permit = 1;	// permit the buffer to write to the CDB
		cdb_active = 1;	// the arbiter would set this
		# 2
		$display("A full clock cycle has NOT passed since the last signals were printed.");
		$display("The output buffer has been permitted to write to the CDB, verify that the");
		$display("result is present on the CDB, as well as the reorder buffer tag (%d).", reorder_buffer_tag_in);
		display_signals();

		# 8
		$display("The rest of the clock cycle has passed.  Since the ROB tag appeared on the");
		$display("CDB while the CDB was designated as active, verify that the reservation station");
		$display("has had its signals reset.");
		display_signals();
		$finish();
	end

	task display_signals();
		$display("-------------------------------------------");
		$display("RESERVATION STATION SIGNALS");
		$display("q1_out: %d, v1_out: %d", q1_out, v1_out);
		$display("q2_out: %d, v2_out: %d", q2_out, v2_out);
		$display("alu_op_out: %d, alu_sign_out: %d", alu_op_out, alu_sign_out);
		$display("busy: %d, ready_to_execute: %d", busy, ready_to_execute);

		$display("-------------------------------------------");
		$display("FUNCTIONAL UNIT SIGNALS");
		$display("accept: %d, result: %d", fu_accept, fu_result);
		$display("write_to_buffer: %d", fu_write_to_buf);

		$display("-------------------------------------------");
		$display("OUTPUT BUFFER SIGNALS");
		$display("not_empty: %d", output_buf_not_empty);
		$display("cdb_data: %d, cdb_tag: %d", cdb_data, cdb_tag);
		$display("===========================================");
	endtask
endmodule
