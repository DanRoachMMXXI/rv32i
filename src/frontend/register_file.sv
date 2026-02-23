module register_file #(parameter XLEN=32) (
	input logic clk,
	input logic reset,

	// indices for read
	input logic [4:0]	rs1_index,
	input logic [4:0]	rs2_index,

	// fields for the write
	input logic [4:0]	rd_index,
	input logic [XLEN-1:0]	rd,
	input logic		write_en,

	// outputs for the reads
	output logic [XLEN-1:0]	rs1,
	output logic [XLEN-1:0]	rs2
);

	reg [31:0][XLEN-1:0]	registers;

	// registers
	always_ff @(posedge clk) begin
		registers[0] <= 0;
		for (int i = 1; i < 32; i = i + 1) begin
			if (!reset)
				registers[i] <= 0;
			else
				if (i[4:0] == rd_index && write_en)
					registers[i] <= rd;
		end
	end

	assign rs1 = registers[rs1_index];
	assign rs2 = registers[rs2_index];
endmodule

module rf_rob_tag_table #(parameter ROB_TAG_WIDTH) (
	input logic clk,
	input logic reset,

	// indices for read
	input logic [4:0]		rs1_index,
	input logic [4:0]		rs2_index,

	// fields to update tags when a ROB entry is allocated
	input logic			update_rob_tag_en,	// THIS NEEDS TO NOT BE DONE FOR STORES
	input logic [4:0]		update_rob_tag_index,	// this is the rd_index of the instruction being routed
								// as of now, the instruction being routed is the same as
								// the one for which rs1 and rs2 are being read
	input logic [ROB_TAG_WIDTH-1:0]	rob_tail,

	input logic			flush,
	input logic [ROB_TAG_WIDTH-1:0]	flush_start_tag,

	// fields for the write
	input logic [4:0]		rd_index,
	input logic [ROB_TAG_WIDTH-1:0]	rd_rob_index,	// the index of the ROB entry writing to rd
	input logic			write_en,

	// outputs for the reads
	output logic [ROB_TAG_WIDTH-1:0]	rs1_rob_tag,
	output logic				rs1_rob_tag_valid,
	output logic [ROB_TAG_WIDTH-1:0]	rs2_rob_tag,
	output logic				rs2_rob_tag_valid
);
	reg [31:0][ROB_TAG_WIDTH-1:0]	rob_tag;	// ROB tag of the youngest instruction that will write to this register
							// this is the value that dependent instructions will need to forward from
	reg [31:0]			rob_tag_valid;	// is the rob_tag valid?  need this bit since 0 is a valid tag.

	always_ff @(posedge clk) begin
		// register 0 is hardwired to 0
		rob_tag[0] <= 0;
		rob_tag_valid[0] <= 0;
	
		for (int i = 1; i < 32; i = i + 1) begin
			if (!reset || (flush && rob_tag_valid[i] && !($signed(rob_tag[i] - flush_start_tag) < 0))) begin
				rob_tag[i] <= 0;
				rob_tag_valid[i] <= 0;
			end else begin
				// If a new entry is being allocated, that needs to take priority and
				// overwrite the logic that clears the tag and valid bit.
				// If misspeculated instructions are being flushed, it's important to
				// not update the ROB tag metadata for an instruction that's being
				// flushed.
				if (i[4:0] == update_rob_tag_index && update_rob_tag_en && !flush) begin
					rob_tag[i] <= rob_tail;
					rob_tag_valid[i] <= 1;
				end
				// clear the rob tag in the RF only if this is the youngest
				// instruction that will write to rd.  if the tag doesn't match,
				// a younger instruction updated the tag, and subsequent instructions
				// will need to forward from that ROB index.
				else if (i[4:0] == rd_index && write_en && rd_rob_index == rob_tag[i]) begin
					rob_tag[i] <= 0;
					rob_tag_valid[i] <= 0;	// this is what's important
				end

			end
		end
	end
	
	assign rs1_rob_tag = rob_tag[rs1_index];
	assign rs1_rob_tag_valid = rob_tag_valid[rs1_index];

	assign rs2_rob_tag = rob_tag[rs2_index];
	assign rs2_rob_tag_valid = rob_tag_valid[rs2_index];
endmodule
