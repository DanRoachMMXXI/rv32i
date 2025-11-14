module test_functional_unit_output_buffer;
	logic clk = 0;
	logic reset = 0;

	/* input */	logic [31:0] value;
	/* input */	logic [31:0] tag;
	/* input */	logic write_en;
	/* output */	logic not_empty;
	/* input */	logic cdb_permit;
	/* output */	wire [31:0] cdb_data;
	/* output */	wire [31:0] cdb_tag;
	/* debug */	logic [1:0] read_from;
	/* debug */	logic [1:0] write_to;

	functional_unit_output_buffer #(.XLEN(32), .TAG_WIDTH(32)) buffer (
		.clk(clk),
		.reset(reset),
		.value(value),
		.tag(tag),
		.write_en(write_en),
		.not_empty(not_empty),
		.cdb_permit(cdb_permit),
		.cdb_data(cdb_data),
		.cdb_tag(cdb_tag),
		.read_from(read_from),
		.write_to(write_to));

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
		$display("Values exist on the inputs, but write_en was not set, so we are not expecting to see anything in the buffer.");
		display_signals();

		write_en = 1;
		# 10
		$display("Now write_en has been set, we should see the buffer is not empty, but nothing is being");
		$display("broadcast because it has not been given permission to do so by the cdb_arbiter.");
		display_signals();

		write_en = 0;
		# 10
		cdb_permit = 1;
		$display("Now cdb_permit is set, so we should see the the values get broadcast to the cdb.");
		$display("Note that we must have SOME simulation time pass to see the values appear on the cdb.");
		# 2
		display_signals();

		# 8
		cdb_permit = 0;
		$display("The only value that should have been stored should have been broadcast, now nothing should be in the buffer.");
		display_signals();
		$finish();
	end

	task display_signals();
		$display("=================================");
		$display("functional unit inputs:");
		$display("value = 0x%0h", value);
		$display("tag = 0x%0h", tag);
		$display("write_en = %0d", write_en);
		$display("");
		$display("buffer status output:");
		$display("not_empty: %0d", not_empty);
		$display("");
		$display("cdb arbiter input:");
		$display("cdb_permit: %0d", cdb_permit);
		$display("");
		$display("buffer to cdb outputs:");
		$display("cdb_data: 0x%0h", cdb_data);
		$display("cdb_tag: 0x%0h", cdb_tag);
		$display("");
		$display("debug signals:");
		$display("read_from: %0d", read_from);
		$display("write_to: %0d", write_to);
		$display("=================================");
	endtask
endmodule
