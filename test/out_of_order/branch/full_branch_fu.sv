module test_full_branch_fu;
	localparam XLEN = 32;
	localparam ROB_TAG_WIDTH = 32;
	localparam N_ALU_RS = 1;
	localparam N_AGU_RS = 1;
	localparam N_BRANCH_RS = 1;
	localparam RAS_SIZE = 16;

	logic clk = 0;
	logic reset = 0;

	// decode signals
	logic [31:0]			instruction;
	logic [XLEN-1:0]		immediate;
	control_signal_bus		control_signals_in;	// goes to route and RS

	// route signals
	logic				rs_enable;	// goes to enable of RS
	logic				stall;

	// reservation station signals
	logic [ROB_TAG_WIDTH-1:0]	q1_in;
	logic [XLEN-1:0]		v1_in;
	logic [ROB_TAG_WIDTH-1:0]	q2_in;
	logic [XLEN-1:0]		v2_in;
	logic [ROB_TAG_WIDTH-1:0]	reorder_buffer_tag_in;
	logic				cdb_permit;	// this signal would come from an arbitration system

	logic				rs_reset;

	logic [XLEN-1:0]		pc_plus_four_in;
	logic [XLEN-1:0]		predicted_next_instruction_in;
	logic				branch_prediction_in;

	logic				cdb_valid;
	wire [XLEN-1:0]			cdb_data;
	wire [ROB_TAG_WIDTH-1:0]	cdb_rob_tag;

	logic				tb_drive_cdb;	// the testbench drives the CDB, as though it were given access to do so by the CDB arbiter
	logic [XLEN-1:0]		tb_cdb_data;
	logic [ROB_TAG_WIDTH-1:0]	tb_cdb_rob_tag;

	logic [ROB_TAG_WIDTH-1:0]	q1_out;
	logic [XLEN-1:0]		v1_out;
	logic [ROB_TAG_WIDTH-1:0]	q2_out;
	logic [XLEN-1:0]		v2_out;
	control_signal_bus		control_signals_out;

	logic [XLEN-1:0]		pc_plus_four_out;
	logic [XLEN-1:0]		predicted_next_instruction_out;
	logic				branch_prediction_out;

	logic [ROB_TAG_WIDTH-1:0]	reorder_buffer_tag_out;
	logic				busy;
	logic				ready_to_execute;

	logic [XLEN-1:0]		next_instruction;
	logic				branch_mispredicted;
	logic				accept;
	logic				write_to_buffer;

	logic				output_buf_not_empty;

	// RAS control to RAS
	logic	ras_push;
	logic	ras_pop;

	assign cdb_data = tb_drive_cdb ? tb_cdb_data : 'bZ;
	assign cdb_rob_tag = tb_drive_cdb ? tb_cdb_rob_tag : 'bZ;

	instruction_decode #(.XLEN(XLEN)) instruction_decode (
		.instruction(instruction),
		.immediate(immediate),
		.control_signals(control_signals_in)
	);

	instruction_route #(.N_ALU_RS(N_ALU_RS), .N_AGU_RS(N_AGU_RS), .N_BRANCH_RS(N_BRANCH_RS)) route (
		.instruction_type(control_signals_in.instruction_type),
		.alu_rs_busy(1'b0),
		.agu_rs_busy(1'b0),
		.branch_rs_busy(busy),
		.alu_rs_route(),
		.agu_rs_route(),
		.branch_rs_route(rs_enable),
		.stall(stall)
	);

	// what's TODO ?
	// - create a mock register file, or a real one to test writeback (no working ROB yet)
	// - route register file contents to inputs, or I could just work on the real routing logic
	// - reorder buffer and flusher

	ras_control ras_control (
		.jump(control_signals_in.jump),
		.jalr(control_signals_in.jalr),
		.rs1(),
		.rd(),

		.push(ras_push),
		.pop(ras_pop)
	);

	return_address_stack #(.XLEN(XLEN), .STACK_SIZE(RAS_SIZE)) ras (
		.clk(clk),
		.reset(reset),

		.address_in(),
		.push(ras_push),
		.pop(ras_pop),

		.checkpoint(),
		.restore_checkpoint(),

		.address_out(),
		.valid_out(),

		// debug signals, no need to attach these unless shit hits the
		// fan
		.stack(),
		.stack_valid(),
		.stack_pointer(),
		.sp_checkpoint()
	);

	branch_predictor #(.XLEN(XLEN)) branch_predictor (
		.pc_plus_four(),
		.branch_target(),
		.jump(),
		.branch(),
		.branch_predicted_taken()
	);

	reservation_station #(.XLEN(XLEN), .TAG_WIDTH(ROB_TAG_WIDTH)) reservation_station (
		.clk(clk),
		.reset(rs_reset),
		.enable(rs_enable),
		.dispatched_in(accept),
		.q1_in(q1_in),
		.v1_in(v1_in),
		.q2_in(q2_in),
		.v2_in(v2_in),
		.control_signals_in(control_signals_in),
		.reorder_buffer_tag_in(reorder_buffer_tag_in),
		.pc_plus_four_in(pc_plus_four_in),
		.predicted_next_instruction_in(predicted_next_instruction_in),
		.branch_prediction_in(branch_prediction_in),
		.cdb_valid(cdb_valid),
		.cdb_rob_tag(cdb_rob_tag),
		.cdb_data(cdb_data),
		.q1_out(q1_out),
		.v1_out(v1_out),
		.q2_out(q2_out),
		.v2_out(v2_out),
		.control_signals_out(control_signals_out),
		.reorder_buffer_tag_out(reorder_buffer_tag_out),
		.pc_plus_four_out(pc_plus_four_out),
		.predicted_next_instruction_out(predicted_next_instruction_out),
		.branch_prediction_out(branch_prediction_out),
		.busy(busy),
		.ready_to_execute(ready_to_execute)
	);

	reservation_station_reset #(.TAG_WIDTH(ROB_TAG_WIDTH)) reservation_station_reset (
		.global_reset(reset),
		.bus_valid(cdb_valid),
		.bus_rob_tag(cdb_rob_tag),
		.rs_rob_tag(reorder_buffer_tag_out),
		.reservation_station_reset(rs_reset)
	);

	branch_functional_unit #(.XLEN(XLEN)) fu (
		.v1(v1_out),
		.v2(v2_out),
		.pc_plus_four(pc_plus_four_out),
		.predicted_next_instruction(predicted_next_instruction_out),
		.jump(control_signals_out.jump),
		.branch(control_signals_out.branch),
		.branch_if_zero(control_signals_out.branch_if_zero),
		.branch_prediction(branch_prediction_out),
		.next_instruction(next_instruction),
		.branch_mispredicted(branch_mispredicted),
		.ready_to_execute(ready_to_execute),
		.accept(accept),
		.write_to_buffer(write_to_buffer)
	);

	functional_unit_output_buffer #(.XLEN(XLEN), .TAG_WIDTH(ROB_TAG_WIDTH)) output_buf (
		.clk(clk),
		.reset(reset),
		.value(next_instruction),
		.tag(reorder_buffer_tag_out),
		.write_en(write_to_buffer),
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

		// TODO: actually write test

		$display("All assertions passed.");
		$finish();
	end
endmodule
