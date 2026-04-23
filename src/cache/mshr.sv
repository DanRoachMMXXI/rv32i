module mshr #(
	parameter XLEN=32,
	parameter N_MSHR,
	parameter N_TARGETS,	// the number of missed accesses that can be tracked in a single MSHR
	parameter N_WAYS
) (
	input logic clk,
	input logic reset,

	input logic				memory_op_type_in,
	input logic [XLEN-1:0]			address_in,
	input logic [XLEN-1:0]			data_in,
	input logic [(XLEN/8)-1:0]		byte_mask_in,
	input logic [$clog2(N_WAYS)-1:0]	evicted_way_index_in,

	input logic miss,

	input logic				clear_entry,
	input logic [$clog2(N_MSHR)-1:0]	clear_entry_index,

	// MSHRs
	output reg [N_MSHR-1:0]				mshr_valid,
	output reg [N_MSHR-1:0]				mshr_op_type,	// 0 = read, 1 = write
	output reg [N_MSHR-1:0][XLEN-1:0]		mshr_address,
	output reg [N_MSHR-1:0][XLEN-1:0]		mshr_data,
	output reg [N_MSHR-1:0][(XLEN/8)-1:0]		mshr_byte_mask,
	output reg [N_MSHR-1:0][$clog2(N_WAYS)-1:0]	mshr_evicted_way_index

	// TODO: target missed instructions
	// ChatGPT list of fields in each target entry:
	// Target entry:
	// - request ID / LSU tag
	// - load/store op
	// - byte/half/word size
	// - word/byte offset within line
	// - signed/unsigned (for loads)
	// - store data + byte mask (if merging stores)
	// - destination register / reorder tag (OOO core)

	// output reg [N_MSHR-1:0][N_TARGETS-1:0]		mshr_target_op_type,
	// output reg [N_MSHR-1:0][N_TARGETS-1:0]		mshr_target_rob_tag,
);

	logic [N_MSHR-1:0]		mshr_write_en;
	lsb_fixed_priority_arbiter #(.N(N_MSHR)) mshr_select (
		.in(~mshr_valid),
		.out(mshr_write_en)
	);

	// MSHR synchronous logic
	always_ff @(posedge clk) begin
		for (int i = 0; i < N_MSHR; i = i + 1) begin
			if (!reset || (clear_entry && clear_entry_index == i[$clog2(N_MSHR)-1:0])) begin
				mshr_valid[i] <= 0;
				// mshr_op_type[i] <= 0;
				// mshr_address[i] <= 0;
				// mshr_data[i] <= 0;
				// mshr_byte_mask[i] <= 0;
				// mshr_evicted_way_index[i] <= 0;
			end else if (mshr_write_en[i] && miss) begin
				mshr_valid[i] <= 1;
				mshr_op_type[i] <= memory_op_type_in;
				mshr_address[i] <= address_in;
				mshr_data[i] <= data_in;
				mshr_byte_mask[i] <= byte_mask_in;
				mshr_evicted_way_index[i] <= evicted_way_index_in;
			end
		end
	end
endmodule
