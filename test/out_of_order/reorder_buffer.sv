import instruction_type::*;	// consts for convenience

module test_reorder_buffer;
	localparam XLEN = 32;
	localparam ROB_TAG_WIDTH = 4;
	localparam ROB_BUF_SIZE = 16;

	logic clk;
	logic reset;

	logic input_en;
	logic [1:0] instruction_type_in;
	logic [XLEN-1:0] destination_in;
	logic [XLEN-1:0] value_in;
	logic data_ready_in;
	logic [XLEN-1:0] next_instruction_in;
	logic				cdb_valid;
	logic [XLEN-1:0]		cdb_data;
	logic [ROB_TAG_WIDTH-1:0]	cdb_rob_tag;
	logic				cdb_exception;
	logic agu_address_valid;
	logic [XLEN-1:0] agu_address_data;
	logic [XLEN-1:0] agu_address_rob_tag;
	logic [ROB_BUF_SIZE-1:0]		flush;
	logic [ROB_TAG_WIDTH-1:0]		new_tail;
	logic [ROB_BUF_SIZE-1:0]		rob_valid;
	logic [ROB_BUF_SIZE-1:0][1:0]	rob_instruction_type;
	logic [ROB_BUF_SIZE-1:0]		rob_address_valid;
	logic [ROB_BUF_SIZE-1:0][XLEN-1:0]	rob_destination;
	logic [ROB_BUF_SIZE-1:0][XLEN-1:0]	rob_value;
	logic [ROB_BUF_SIZE-1:0]		rob_data_ready;
	logic [ROB_BUF_SIZE-1:0]		rob_exception;
	logic [ROB_BUF_SIZE-1:0][XLEN-1:0]	rob_next_instruction;
	logic [ROB_TAG_WIDTH-1:0] head;
	logic [ROB_TAG_WIDTH-1:0] tail;
	logic commit;
	logic full;

	logic tb_drive_cdb;	// the testbench drives the CDB, as though it were given access to do so by the CDB arbiter
	logic [XLEN-1:0] tb_cdb_data;
	logic [ROB_TAG_WIDTH-1:0] tb_cdb_rob_tag;
	logic tb_cdb_exception;

	always_comb
		if (tb_drive_cdb) begin
			cdb_data = tb_cdb_data;
			cdb_rob_tag = tb_cdb_rob_tag;
			cdb_exception = tb_cdb_exception;
		end else begin
			cdb_data = 'bZ;
			cdb_rob_tag = 4'bZ;
			cdb_exception = 1'bZ;
		end


	reorder_buffer #(.XLEN(XLEN), .TAG_WIDTH(ROB_TAG_WIDTH), .BUF_SIZE(ROB_BUF_SIZE)) rob (
		.clk(clk),
		.reset(reset),
		.input_en(input_en),
		.instruction_type_in(instruction_type_in),
		.destination_in(destination_in),
		.value_in(value_in),
		.data_ready_in(data_ready_in),
		.next_instruction_in(next_instruction_in),
		.cdb_valid(cdb_valid),
		.cdb_data(cdb_data),
		.cdb_rob_tag(cdb_rob_tag),
		.cdb_exception(cdb_exception),
		.agu_address_valid(agu_address_valid),
		.agu_address_data(agu_address_data),
		.agu_address_rob_tag(agu_address_rob_tag),
		.flush(flush),
		.new_tail(new_tail),
		.rob_valid(rob_valid),
		.rob_instruction_type(rob_instruction_type),
		.rob_address_valid(rob_address_valid),
		.rob_destination(rob_destination),
		.rob_value(rob_value),
		.rob_data_ready(rob_data_ready),
		.rob_exception(rob_exception),
		.rob_next_instruction(rob_next_instruction),
		.head(head),
		.tail(tail),
		.commit(commit),
		.full(full)
	);

	rob_exception_handler #(.BUF_SIZE(ROB_BUF_SIZE), .TAG_WIDTH(ROB_TAG_WIDTH)) rob_exception_handler (
		.rob_exception(rob_exception),
		.rob_head(head),
		.rob_tail(tail),

		.flush(flush),
		.new_tail(new_tail)
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

		// allocate the first entry for an ALU instruction without
		// data ready, storing the result in register 10
		input_en = 1;
		instruction_type_in = ALU;
		destination_in = 10;
		value_in = 'h0000_0000;
		data_ready_in = 0;
		# 10
		assert(rob_valid == 'h0001);
		assert(rob_instruction_type[0] == ALU);
		assert(rob_destination[0] == 10);
		assert(rob_data_ready == 'h0000);
		assert(rob_exception == 'h0000);
		assert(head == 0);
		assert(tail == 1);
		assert(commit == 0);
		assert(full == 0);

		// allocate another entry for a LOAD instruction
		instruction_type_in = LOAD;
		destination_in = 8;	// register 8
		// data not ready... that's the point of loads
		# 10
		assert(rob_valid == 'h0003);
		assert(rob_instruction_type[1] == LOAD);
		assert(rob_destination[1] == 8);
		assert(rob_data_ready == 'h0000);
		assert(rob_address_valid == 'h0000);
		assert(head == 0);
		assert(tail == 2);
		assert(commit == 0);
		assert(full == 0);

		input_en = 0;

		// Provide the value for the ALU instruction this cycle
		drive_cdb('h7867_5645, 0, 0);

		# 10
		assert(rob_data_ready == 'h0001);
		assert(rob_value[0] == 'h7867_5645);
		assert(commit == 1);

		release_cdb();

		// after the next cycle, the ROB should clear its entry at
		// head (0) since it committed
		# 10
		assert(rob_valid == 'h0002);
		assert(head == 1);
		assert(commit == 0);

		// Provide the value for the LOAD instruction this cycle
		// also allocate a conditional branch instruction
		drive_cdb('h6666_7777, 1, 0);

		input_en = 1;
		instruction_type_in = BRANCH;
		destination_in = 0;
		value_in = 0;
		data_ready_in = 0;
		next_instruction_in = 20;
		# 10
		assert(rob_valid == 'h0006);
		assert(commit == 1);	// so this entry should be cleared next cycle

		release_cdb();
		
		// allocating a STORE to test address stuff for commit
		// no destination or data
		instruction_type_in = STORE;
		next_instruction_in = 24;
		# 10
		assert(rob_valid == 'h000C);
		assert(commit == 0);

		input_en = 0;

		// I'll give the data to the store first, then verify no
		// commit until the branch receives its data
		drive_cdb('h1212_2323, 3, 0);
		# 10
		assert(rob_valid == 'h000C);
		assert(rob_data_ready == 'h0008);
		assert(rob_address_valid == 'h0000);

		release_cdb();

		agu_address_valid = 1;
		agu_address_data = 'h5555_4444;
		agu_address_rob_tag = 3;
		# 10
		assert(rob_address_valid == 'h0008);
		// now the STORE at index 3 is ready to commit, but the BRANCH
		// at index 2 is not, so the ROB should not commit this cycle.
		assert(commit == 0);

		agu_address_valid = 0;

		drive_cdb('h4321_1234, 2, 0);
		# 10
		assert(rob_data_ready == 'h000C);
		assert(commit == 1);
		assert(head == 2);

		release_cdb();
		# 10
		// now the branch has committed and should be freed from the
		// ROB, now the store is at the head and ready to commit, so
		// we should commit again.
		assert(rob_valid == 'h0008);
		assert(commit == 1);
		assert(head == 3);

		# 10
		// now the buffer should be empty again
		assert(rob_valid == 'h0000);
		assert(commit == 0);
		assert(head == 4);

		// now we need to test flushing the buffer on an exception
		// start by populating the buffer with a few instructions
		input_en = 1;
		instruction_type_in = ALU;
		destination_in = 0;
		value_in = 'h0000_0000;
		data_ready_in = 0;
		# 10
		instruction_type_in = STORE;
		# 10
		instruction_type_in = BRANCH;
		# 10
		instruction_type_in = LOAD;
		# 10
		instruction_type_in = STORE;
		# 10
		instruction_type_in = ALU;
		# 10
		input_en = 0;
		// now the ROB is populated like so:
		// index	instruction_type
		// 4		ALU
		// 5		STORE
		// 6		BRANCH
		// 7		LOAD
		// 8		STORE
		// 9		ALU
		// now we are going to make the branch have a mispredict
		// exception (or any exception, right now it is all the same)
		// so all the instructions following the branch need to be
		// flushed
		drive_cdb(0, 6, 1);
		# 10
		release_cdb();
		assert(flush == 'h0380);
		# 10
		assert(rob_valid == 'h0070);

		$display("All assertions passed.");
		$finish();
	end

	function void drive_cdb(logic [XLEN-1:0] data, logic [ROB_TAG_WIDTH-1:0] tag, logic exception);
		cdb_valid = 1;
		tb_drive_cdb = 1;
		tb_cdb_data = data;
		tb_cdb_rob_tag = tag;
		tb_cdb_exception = exception;
	endfunction

	function void release_cdb();
		cdb_valid = 0;
		tb_drive_cdb = 0;
	endfunction
endmodule
