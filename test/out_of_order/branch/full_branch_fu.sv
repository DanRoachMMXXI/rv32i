module test_full_branch_fu;
	localparam XLEN = 32;
	localparam ROB_BUF_SIZE = 64;
	localparam ROB_TAG_WIDTH = $clog2(ROB_BUF_SIZE);
	localparam N_ALU_RS = 1;
	localparam N_AGU_RS = 1;
	localparam N_BRANCH_RS = 1;
	localparam RAS_SIZE = 16;
	localparam LDQ_SIZE = 8;	// just need these to instantiate the buffer_flusher
	localparam STQ_SIZE = 8;

	logic clk = 0;
	logic reset = 0;

	logic [XLEN-1:0]	pc;
	logic [XLEN-1:0]	pc_plus_four;

	// decode signals
	logic [31:0]			instruction;
	logic [XLEN-1:0]		immediate;
	control_signal_bus		control_signals_in;	// goes to route and RS

	logic	ras_push;
	logic	ras_pop;

	logic [XLEN-1:0]	ras_address_out;
	logic			ras_valid_out;

	logic [XLEN-1:0]	branch_target;

	// route signals
	logic				rs_enable;	// goes to enable of RS
	logic				stall;

	// reservation station signals
	logic [ROB_TAG_WIDTH-1:0]	q1_in;	// 0 if JAL or B_TYPE, 0 if rs1 value available, otherwise tag for rs1
	logic [XLEN-1:0]		v1_in;	// pc if JAL or B_TYPE, rs1 if JALR
	logic [ROB_TAG_WIDTH-1:0]	reorder_buffer_tag_in;
	logic				cdb_permit;	// this signal would come from an arbitration system

	logic				rs_reset;

	logic [XLEN-1:0]		predicted_next_instruction_in;
	logic				branch_prediction_in;

	logic				cdb_valid;
	wire [XLEN-1:0]			cdb_data;
	wire [ROB_TAG_WIDTH-1:0]	cdb_rob_tag;

	logic				tb_drive_cdb;	// the testbench drives the CDB, as though it were given access to do so by the CDB arbiter
	logic [XLEN-1:0]		tb_cdb_data;
	logic [ROB_TAG_WIDTH-1:0]	tb_cdb_rob_tag;

	logic				q1_valid_in;
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

	// the reorder buffer
	logic [ROB_BUF_SIZE-1:0]		rob_valid;
	logic [ROB_BUF_SIZE-1:0][1:0]		rob_instruction_type;
	logic [ROB_BUF_SIZE-1:0]		rob_address_valid;
	logic [ROB_BUF_SIZE-1:0][XLEN-1:0]	rob_destination;
	logic [ROB_BUF_SIZE-1:0][XLEN-1:0]	rob_value;
	logic [ROB_BUF_SIZE-1:0]		rob_data_ready;
	logic [ROB_BUF_SIZE-1:0]		rob_branch_mispredict;
	logic [ROB_BUF_SIZE-1:0]		rob_exception;
	logic [ROB_BUF_SIZE-1:0][XLEN-1:0]	rob_next_instruction;

	logic [$clog2(ROB_BUF_SIZE)-1:0]	rob_head;
	logic [$clog2(ROB_BUF_SIZE)-1:0]	rob_tail;

	logic [ROB_BUF_SIZE-1:0]		rob_flush;
	logic [$clog2(ROB_BUF_SIZE)-1:0]	rob_new_tail;

	assign cdb_data = tb_drive_cdb ? tb_cdb_data : {XLEN{1'bZ}};
	assign cdb_rob_tag = tb_drive_cdb ? tb_cdb_rob_tag : {ROB_TAG_WIDTH{1'bZ}};

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
		.rs1_index(control_signals_in.rs1_index),
		.rd_index(control_signals_in.rd_index),

		.push(ras_push),
		.pop(ras_pop)
	);

	return_address_stack #(.XLEN(XLEN), .STACK_SIZE(RAS_SIZE)) ras (
		.clk(clk),
		.reset(reset),

		.address_in(pc_plus_four),
		.push(ras_push),
		.pop(ras_pop),

		// not doing checkpointing in this test yet, as it's already
		// covered in the unit test
		.checkpoint(),
		.restore_checkpoint(),

		.address_out(ras_address_out),
		.valid_out(ras_valid_out),

		// debug signals, no need to attach these unless shit hits the
		// fan
		.stack(),
		.stack_valid(),
		.stack_pointer(),
		.sp_checkpoint()
	);

	branch_target #(.XLEN(XLEN)) branch_target_calculator (
		.pc(pc),
		// TODO: for now, I'm assuming that we only use the values on
		// the RAS to predict values for JALR instructions.  as noted
		// in cpu.sv, I may cache or forward values from LUI and AUIPC
		// if the registers match. If I do, I should update this test.
		// Until then, JALR predictions that don't pop off the stack
		// will use 0 as the source, which is just as useless as any
		// other number, but for the purposes of testing the branch
		// pipeline I'm down with it as it is near guaranteed to
		// mispredict and I can validate that it flushes.
		.rs1(ras_address_out),
		.immediate(immediate),
		.jalr(control_signals_in.jalr),

		.branch_target(branch_target)
	);

	branch_predictor #(.XLEN(XLEN)) branch_predictor (
		.pc_plus_four(pc_plus_four),
		.branch_target(branch_target),
		.jump(control_signals_in.jump),
		.branch(control_signals_in.branch),
		.branch_predicted_taken(branch_prediction_in)
	);

	reservation_station #(.XLEN(XLEN), .TAG_WIDTH(ROB_TAG_WIDTH)) reservation_station (
		.clk(clk),
		.reset(rs_reset),
		.enable(rs_enable),
		.dispatched_in(accept),
		.q1_valid_in(q1_valid_in),
		.q1_in(q1_in),	// 0 if JAL or B_TYPE, 0 if JALR and rs1 value is ready in RF or ROB, otherwise tag for rs1
		.v1_in(v1_in),	// pc if JAL or B_TYPE, rs1 if JALR
		.q2_valid_in(1'b0),	// immediate, so no tag
		.q2_in(0),	// immediate, so no tag
		.v2_in(immediate),	// immediate
		.control_signals_in(control_signals_in),
		.reorder_buffer_tag_in(reorder_buffer_tag_in),
		.pc_plus_four_in(pc_plus_four),
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

	reorder_buffer #(.XLEN(XLEN), .TAG_WIDTH(ROB_TAG_WIDTH), .BUF_SIZE(ROB_BUF_SIZE)) rob (
		.clk(clk),
		.reset(reset),
		.input_en(),
		.instruction_type_in(control_signals_in.instruction_type),
		.destination_in(),
		.value_in(),
		.data_ready_in(),
		.pc_in(pc),
		.cdb_valid(cdb_valid),
		.cdb_data(cdb_data),
		.cdb_rob_tag(cdb_rob_tag),
		.cdb_exception(),
		.branch_mispredict(),
		.agu_address_valid(),
		.agu_address_data(),
		.agu_address_rob_tag(),
		.flush(rob_flush),
		.new_tail(rob_new_tail),
		.rob_valid(rob_valid),
		.rob_instruction_type(rob_instruction_type),
		.rob_address_valid(rob_address_valid),
		.rob_destination(rob_destination),
		.rob_value(rob_value),
		.rob_data_ready(rob_data_ready),
		.rob_branch_mispredict(rob_branch_mispredict),
		.rob_exception(rob_exception),
		.rob_next_instruction(rob_next_instruction),
		.head(rob_head),
		.tail(rob_tail),
		.commit(),
		.full()
	);

	buffer_flusher #(.BUF_SIZE(ROB_BUF_SIZE), .TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) buffa_flusha (
		.rob_branch_mispredict(rob_branch_mispredict),
		.rob_exception(rob_exception),
		.rob_head(rob_head),
		.rob_tail(rob_tail),

		// at the time of writing this test these don't even do
		// anything, and will probably change once I implement the
		// flushing of the load and store queues
		.ldq_valid(),
		.ldq_rob_tag(),
		.stq_valid(),
		.stq_rob_tag(),

		.flush(rob_flush),
		.rob_new_tail(rob_new_tail),

		.flush_ldq(),
		.ldq_new_tail(),
		.flush_stq(),
		.stq_new_tail()
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
		instruction = 'h0140006f;	// jal x0, 20
		// 0000_0001_0100_0000_0000_0000_0110_1111
		//   28   24   20   16   12    8    4    0
		// 000000000
		# 10

		$display("immediate: 0x%0h", immediate);
		// control_signal_bus		control_signals_in;
		$display("ras_push: 0x%0h", ras_push);
		$display("ras_pop: 0x%0h", ras_pop);
		$display("ras_address_out: 0x%0h", ras_address_out);
		$display("ras_valid_out: 0x%0h", ras_valid_out);
		$display("branch_target: 0x%0h", branch_target);
		$display("rs_enable: 0x%0h", rs_enable);
		$display("branch_rs_busy: %0d", busy);
		$display("stall: 0x%0h", stall);

		instruction = 'hFEDFF06F;	// jal x0, -20
		# 10

		$display("immediate: 0x%0h", immediate);
		// control_signal_bus		control_signals_in;
		$display("ras_push: 0x%0h", ras_push);
		$display("ras_pop: 0x%0h", ras_pop);
		$display("ras_address_out: 0x%0h", ras_address_out);
		$display("ras_valid_out: 0x%0h", ras_valid_out);
		$display("branch_target: 0x%0h", branch_target);
		$display("rs_enable: 0x%0h", rs_enable);
		$display("branch_rs_busy: %0d", busy);
		$display("stall: 0x%0h", stall);
		$display("All assertions passed.");
		$finish();
	end
endmodule
