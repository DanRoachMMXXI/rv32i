module register_file
	#(parameter XLEN=32, parameter ROB_TAG_WIDTH=32) (
	input logic clk,
	input logic reset,

	// indices for read
	input logic [4:0]	rs1_index,
	input logic [4:0]	rs2_index,

	// fields to update tags when a ROB entry is allocated
	input logic			rob_entry_alloc,
	input logic [4:0]		rob_alloc_rd_index,
	input logic [ROB_TAG_WIDTH-1:0] rob_alloc_tag,

	// fields for the write
	input logic [4:0] rd_index,
	input logic [XLEN-1:0] rd,
	input logic [ROB_TAG_WIDTH-1:0]	rd_rob_index,	// the index of the ROB entry writing to rd
	input logic write_en,

	// outputs for the reads
	output logic [XLEN-1:0]			rs1,
	output logic [ROB_TAG_WIDTH-1:0]	rs1_rob_tag,
	output logic				rs1_rob_tag_valid,
	output logic [XLEN-1:0]			rs2,
	output logic [ROB_TAG_WIDTH-1:0]	rs2_rob_tag,
	output logic				rs2_rob_tag_valid
);

	reg [31:0][XLEN-1:0]		registers;
	reg [31:0][ROB_TAG_WIDTH-1:0]	rob_tag;	// ROB tag of the youngest instruction that will write to this register
							// this is the value that dependent instructions will need to forward from
	reg [31:0]			rob_tag_valid;	// is the rob_tag valid?  need this bit since 0 is a valid tag.
	integer i;

	// register 0 is hardwired to 0
	assign registers[0] = 0;
	assign rob_tag[0] = 0;
	assign rob_tag_valid[0] = 0;
	
	always @(posedge clk) begin
		if (!reset) begin
			for (i = 1; i < 32; i = i + 1) begin
				registers[i] <= 0;
				rob_tag[i] <= 0;
				rob_tag_valid[i] <= 0;
			end
		end else begin
			if (write_en && rd_index != 0) begin
				registers[rd_index] <= rd;

				// clear the rob tag in the RF only if this is
				// the youngest instruction that will write to
				// rd.  if the tag doesn't match, a younger
				// instruction updated the tag, and subsequent
				// instructions will need to forward from that
				// ROB index.
				if (rob_tag_valid[rd_index] && rd_rob_index == rob_tag[rd_index]) begin
					rob_tag[rd_index] <= 0;
					rob_tag_valid[rd_index] <= 0;	// this is what's important
				end
			end

			// I think this needs to come after the above
			// writeback logic, cause if an entry is allocated,
			// that needs to take priority and overwrite the logic
			// that clears the tag and valid bit
			if (rob_entry_alloc && rob_alloc_rd_index != 0) begin
				rob_tag[rob_alloc_rd_index] <= rob_alloc_tag;
				rob_tag_valid[rob_alloc_rd_index] <= 1;
			end
		end
	end
	
	assign rs1 = registers[rs1_index];
	assign rs1_rob_tag = rob_tag[rs1_index];
	assign rs1_rob_tag_valid = rob_tag_valid[rs1_index];

	assign rs2 = registers[rs2_index];
	assign rs2_rob_tag = rob_tag[rs2_index];
	assign rs2_rob_tag_valid = rob_tag_valid[rs2_index];
endmodule
