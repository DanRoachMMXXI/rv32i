// total bytes of this cache = N_SETS * N_WAYS * BLOCK_SIZE
module cache_data_memory #(
	parameter N_SETS,
	parameter N_WAYS,
	parameter BLOCK_SIZE	// in bytes
) (
	input logic	clk,
	// input logic	reset,	// maybe no need to reset since valid bits are used

	input logic				write_en,
	// input logic [XLEN-1:0]		block_address_in,
	input logic [$clog2(N_SETS)-1:0]	set_index,
	input logic [$clog2(N_WAYS)-1:0]	way_index,
	input logic [BLOCK_SIZE-1:0][7:0]	block_data_in,

	output logic [BLOCK_SIZE-1:0][7:0]	block_data_out
);

	reg [N_SETS-1:0][N_WAYS-1:0][BLOCK_SIZE-1:0][7:0] cache_data;

	always_ff @(posedge clk) begin
		if (write_en) begin
			cache_data[set_index][way_index] <= block_data_in;
		end
	end

	assign block_data_out = cache_data[set_index][way_index];
endmodule
