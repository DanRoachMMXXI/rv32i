module youngest_entry_select_tb;
	logic [15:0] queue_valid_bits;
	logic [3:0] head_index;
	logic [15:0] select_mask;
	logic [3:0] youngest_index;

	youngest_entry_select #(.QUEUE_SIZE(16)) dut (
		.queue_valid_bits(queue_valid_bits),
		.head_index(head_index),
		.select_mask(select_mask),
		.youngest_index(youngest_index)
	);

	initial begin
		// NOTE THAT NO TEST VALIDATES THE BEHAVIOR OF
		// queue_valid_bits = 'h0000;
		// THAT IS BECAUSE THE OUTPUT OF THIS MODULE WILL BE
		// DISREGARDED IF THERE ARE NO MATCHING ENTRIES

		queue_valid_bits = 'b0101010101010101;
		head_index = 0;
		# 10
		assert(select_mask == 'h4000);
		assert(youngest_index == 14);

		head_index = 5;
		# 10
		assert(select_mask == 'h0010);
		assert(youngest_index == 4);

		head_index = 6;
		# 10
		assert(select_mask == 'h0010);
		assert(youngest_index == 4);

		// some more realistic examples
		queue_valid_bits = 'h07FC;
		head_index = 2;
		# 10
		assert(select_mask == 'h0400);
		assert(youngest_index == 10);

		queue_valid_bits = 'hF81F;
		head_index = 11;
		# 10
		assert(select_mask == 'h0010);
		assert(youngest_index == 4);

		head_index = 0;
		queue_valid_bits = 'hFFFF;
		# 10
		assert(youngest_index == 15);

		head_index = 0;
		queue_valid_bits = 'h0001;
		# 10
		assert(youngest_index == 0);

		// these tests are going to more closely resemble what the
		// component is going to see in the context it was designed
		// for: a couple of stores match an address, select the
		// furthest one from the head pointer.
		head_index = 12;
		queue_valid_bits='h8032;
		# 10
		assert(youngest_index == 5);

		head_index = 6;
		queue_valid_bits = 'h1200;
		# 10
		assert(youngest_index == 12);

		head_index = 2;
		queue_valid_bits = 'h8000;
		# 10
		assert(youngest_index == 15);

		head_index = 2;
		queue_valid_bits = 'h0002;
		# 10
		assert(youngest_index == 1);

		$display("All assertions passed");
		$finish();
	end
endmodule
