module test_functional_unit_output_buffer;
	localparam XLEN = 32;
	localparam ROB_SIZE = 16;
	localparam ROB_TAG_WIDTH = $clog2(ROB_SIZE);

	logic clk = 0;
	logic reset = 0;

	/* input */	logic [XLEN-1:0]		value;
	/* input */	logic [ROB_TAG_WIDTH-1:0]	tag;
	/* input */	logic				exception;
	/* input */	logic				redirect_mispredicted;
	/* input */	logic				write_en;
	/* input */	logic				data_bus_permit;
	/* output */	wire [XLEN-1:0]			data_bus_data;
	/* output */	wire [ROB_TAG_WIDTH-1:0]	data_bus_tag;
	/* output */	wire				data_bus_exception;
	/* output */	wire				data_bus_redirect_mispredicted;
	/* output */	logic				not_empty;
	/* output */	logic				full;

	functional_unit_output_buffer #(.XLEN(XLEN), .ROB_SIZE(ROB_SIZE), .ROB_TAG_WIDTH(ROB_TAG_WIDTH)) buffer (
		.clk(clk),
		.reset(reset),
		.value(value),
		.tag(tag),
		.exception(exception),
		.redirect_mispredicted(redirect_mispredicted),
		.write_en(write_en),
		.data_bus_permit(data_bus_permit),
		.data_bus_data(data_bus_data),
		.data_bus_tag(data_bus_tag),
		.data_bus_exception(data_bus_exception),
		.data_bus_redirect_mispredicted(data_bus_redirect_mispredicted),
		.not_empty(not_empty),
		.full(full)
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
		value = 1;
		tag = 2;
		write_en = 0;
		# 10
		// Values exist on the inputs, but write_en was not set, so we
		// are not expecting to see anything in the buffer.
		assert(not_empty == 0);

		write_en = 1;
		# 10
		// Now write_en has been set, we should see the buffer is not
		// empty, but nothing is being broadcast because it has not
		// been given permission to do so by the cdb_arbiter.
		assert(not_empty == 1);
		assert(full == 0);

		write_en = 0;
		# 10
		data_bus_permit = 1;
		// Now data_bus_permit is set, so we should see the the values
		// get broadcast to the cdb. Note that we must have SOME
		// simulation time pass to see the values appear on the cdb.
		# 2
		assert(data_bus_data == 1);
		assert(data_bus_tag == 2);

		# 8
		data_bus_permit = 0;
		// The only value that should have been stored should have
		// been broadcast, now nothing should be in the buffer.
		assert(not_empty == 0);

		$display("All assertions passed.");
		$finish();
	end
endmodule
