module fill_buffer #(
	parameter XLEN=32,
	parameter BUF_SIZE,
	parameter BLOCK_SIZE
) (
	input logic	clk,
	input logic	reset,

	input logic				fetch_valid,
	input logic [XLEN-1:0]			fetched_block_address,
	input logic [BLOCK_SIZE-1:0][7:0]	fetched_block_data,

	input logic	fill,

	output logic [$clog2(BUF_SIZE):0]	head,
	output logic [$clog2(BUF_SIZE):0]	tail,

	output logic [BUF_SIZE-1:0]				buf_valid,	// necessary for parallel search of the buffer
	output logic [BUF_SIZE-1:0][XLEN-1:0]			buf_block_address,
	output logic [BUF_SIZE-1:0][BLOCK_SIZE-1:0][7:0]	buf_block_data,

	output logic	full,
	output logic	empty
);
	logic [$clog2(BUF_SIZE)-1:0]	head_index;
	logic [$clog2(BUF_SIZE)-1:0]	tail_index;
	assign head_index = head[$clog2(BUF_SIZE)-1:0];
	assign tail_index = tail[$clog2(BUF_SIZE)-1:0];

	always_ff @(posedge clk) begin
		if (!reset) begin
			head <= 0;
			tail <= 0;

			buf_valid <= 0;
		end else begin
			if (fetch_valid) begin
				buf_valid[tail_index] <= 1;
				buf_block_address[tail_index] <= fetched_block_address;
				buf_block_data[tail_index] <= fetched_block_data;
				tail <= tail + 1;
			end

			if (fill) begin
				buf_valid[head_index] <= 0;
				head <= head + 1;
			end
		end
	end

	assign empty = (head == tail);
	assign full = ((tail - head) == BUF_SIZE);
endmodule
