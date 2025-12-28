/*
 * this is effectively a MSB priority encoder, implemented by rotating the
 * valid bits of the queue such that the head of the queue is at index 0, then
 * using a MSB one-hot select, doing the reverse rotation such that the head
 * is back at head_index, then writing the index of the one-hot signal to the
 * output.
 *
 * this was written for use in the store dependence and forwarding logic to
 * select the youngest dependent store to see if data is available for
 * forwarding.
 */
module youngest_entry_select #(parameter QUEUE_SIZE=32) (
	input logic [QUEUE_SIZE-1:0] queue_valid_bits,
	input logic [$clog2(QUEUE_SIZE)-1:0] head_index,

	// any_entry_valid is just the bitwise or of queue_valid_bits to know
	// if youngest_index is valid or just a default 0
	output logic any_entry_valid,
	output logic [$clog2(QUEUE_SIZE)-1:0] youngest_index
	);

	logic [QUEUE_SIZE-1:0] rotated_valid_bits;	// rotates queue_valid_bits so that the head is at index 0
	assign rotated_valid_bits = (queue_valid_bits >> head_index | queue_valid_bits << (QUEUE_SIZE - head_index));

	logic [QUEUE_SIZE-1:0] mask;	// bitmask to generate the MSB one-hot signal

	// youngest_one_hot, but where the head is at index 0 before it gets rotated back to head_index
	logic [QUEUE_SIZE-1:0] rotated_youngest_one_hot;
	logic [QUEUE_SIZE-1:0] youngest_one_hot;	// one-hot signal for the youngest valid entry

	assign mask[QUEUE_SIZE-1] = 1'b0;
	assign mask[QUEUE_SIZE-2:0] = mask[QUEUE_SIZE-1:1] | rotated_valid_bits[QUEUE_SIZE-1:1];
	assign rotated_youngest_one_hot = rotated_valid_bits & ~mask;
	assign youngest_one_hot = (
		rotated_youngest_one_hot << head_index
		| rotated_youngest_one_hot >> (QUEUE_SIZE - head_index)
	);

	assign any_entry_valid = |queue_valid_bits;

	integer i;
	always_comb begin
		youngest_index = 0;
		for (i = 0; i < QUEUE_SIZE; i = i + 1) begin
			if (youngest_one_hot[i]) begin
				youngest_index = i[$clog2(QUEUE_SIZE)-1:0];
			end
		end
	end

endmodule
