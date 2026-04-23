module test_mshr;
	localparam XLEN=32;
	localparam N_MSHR=4;
	localparam N_WAYS=2;

	logic clk;
	logic reset;

	logic				memory_op_type_in;
	logic [XLEN-1:0]		address_in;
	logic [XLEN-1:0]		data_in;
	logic [(XLEN/8)-1:0]		byte_mask_in;
	logic [$clog2(N_WAYS)-1:0]	evicted_way_index_in;

	logic miss;

	logic				clear_entry;
	logic [$clog2(N_MSHR)-1:0]	clear_entry_index;

	// MSHRs
	logic [N_MSHR-1:0]			mshr_valid;
	logic [N_MSHR-1:0]			mshr_op_type;	// 0 = read, 1 = write
	logic [N_MSHR-1:0][XLEN-1:0]		mshr_address;
	logic [N_MSHR-1:0][XLEN-1:0]		mshr_data;
	logic [N_MSHR-1:0][(XLEN/8)-1:0]	mshr_byte_mask;
	logic [N_MSHR-1:0][$clog2(N_WAYS)-1:0]	mshr_evicted_way_index;

	mshr #(.XLEN(XLEN), .N_MSHR(N_MSHR), .N_WAYS(N_WAYS)) mshr (
		.clk(clk),
		.reset(reset),
		.memory_op_type_in(memory_op_type_in),
		.address_in(address_in),
		.data_in(data_in),
		.byte_mask_in(byte_mask_in),
		.evicted_way_index_in(evicted_way_index_in),
		.miss(miss),
		.clear_entry(clear_entry),
		.clear_entry_index(clear_entry_index),
		.mshr_valid(mshr_valid),
		.mshr_op_type(mshr_op_type),
		.mshr_address(mshr_address),
		.mshr_data(mshr_data),
		.mshr_byte_mask(mshr_byte_mask),
		.mshr_evicted_way_index(mshr_evicted_way_index)
	);

	// disable the active low reset after the first clock cycle
	initial begin
		#10 reset = 1;
	end

	always begin
		#5 clk = ~clk;
	end

	initial begin
		# 10	// wait for reset
		// nothing should be valid in the MSHR
		assert(mshr_valid == 0);

		address_in = 'h02468ACE;
		data_in = 'h13579BDF;
		byte_mask_in = 4'b0110;	// not realistic but all good for this test
		memory_op_type_in = 1'b1;
		# 10
		// miss wasn't set, so nothing should have been placed in the MSHR
		assert(mshr_valid == 0);

		miss = 1;
		# 10
		// verify that it was allocated in the LSB available index
		assert(mshr_valid[0] == 1'b1);
		assert(mshr_op_type[0] == 1'b1);
		assert(mshr_address[0] == 'h02468ACE);
		assert(mshr_data[0] == 'h13579BDF);
		assert(mshr_byte_mask[0] == 'b0110);

		miss = 0;
		clear_entry = 1;
		clear_entry_index = 0;
		# 10
		assert(mshr_valid == 0);

		clear_entry = 0;

		address_in = 'hAAAAAAAA;
		data_in = 'hAAAAAAAA;
		memory_op_type_in = 1'b0;
		byte_mask_in = 'hA;
		miss = 1;
		# 10
		assert(mshr_valid[0] == 1'b1);
		assert(mshr_op_type[0] == 1'b0);
		assert(mshr_address[0] == 'hAAAAAAAA);
		assert(mshr_data[0] == 'hAAAAAAAA);
		assert(mshr_byte_mask[0] == 'hA);

		address_in = 'hBBBBBBBB;
		data_in = 'hBBBBBBBB;
		memory_op_type_in = 1'b1;
		byte_mask_in = 'hB;
		# 10
		assert(mshr_valid[1] == 1'b1);
		assert(mshr_op_type[1] == 1'b1);
		assert(mshr_address[1] == 'hBBBBBBBB);
		assert(mshr_data[1] == 'hBBBBBBBB);
		assert(mshr_byte_mask[1] == 'hB);

		address_in = 'hCCCCCCCC;
		data_in = 'hCCCCCCCC;
		memory_op_type_in = 1'b0;
		byte_mask_in = 'hC;

		// on the clock edge, clear an entry to create a hole that should be filled on the
		// following allocation
		clear_entry = 1'b1;
		clear_entry_index = 1;

		# 10
		assert(mshr_valid[2] == 1'b1);
		assert(mshr_op_type[2] == 1'b0);
		assert(mshr_address[2] == 'hCCCCCCCC);
		assert(mshr_data[2] == 'hCCCCCCCC);
		assert(mshr_byte_mask[2] == 'hC);

		assert(mshr_valid[1] == 1'b0);

		clear_entry = 0;

		address_in = 'hDDDDDDDD;
		data_in = 'hDDDDDDDD;
		memory_op_type_in = 1'b1;
		byte_mask_in = 'hD;
		# 10
		// verify that it filled the hole when the 0xBBBBBBBB entry was cleared
		assert(mshr_valid[1] == 1'b1);
		assert(mshr_op_type[1] == 1'b1);
		assert(mshr_address[1] == 'hDDDDDDDD);
		assert(mshr_data[1] == 'hDDDDDDDD);
		assert(mshr_byte_mask[1] == 'hD);

		miss = 0;

		$display("All assertions passed.");
		$finish();
	end
endmodule
