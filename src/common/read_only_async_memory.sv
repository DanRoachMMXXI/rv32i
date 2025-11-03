module read_only_async_memory #(
	parameter MEM_SIZE=2048,	// bytes
	parameter MEM_FILE = "") (
	input logic clk,
	input logic reset,	// active low reset
	
	input logic [$clog2(MEM_SIZE)-1:0] address,

	input logic [3:0] read_byte_en,		// enable each byte of the output
	output logic [31:0] data_out
	);

	logic [7:0] memory [0:MEM_SIZE-1];	// 1-byte entries
	integer i;	// loop var for clearing memory on reset

	always @ (posedge clk) begin
		if (!reset) begin
			// Reset to the fixed memory image if provided
			// or set the entire memory to 0 if not
			if (MEM_FILE != "") begin
				$readmemh(MEM_FILE, memory);
			end else begin
				for (i = 0; i < MEM_SIZE - 1; i = i + 1) begin
					memory[i] = 0;
				end
			end
		end
	end

	assign data_out = {
		memory[address + 3] & {8{read_byte_en[3]}},
		memory[address + 2] & {8{read_byte_en[2]}},
		memory[address + 1] & {8{read_byte_en[1]}},
		memory[address + 0] & {8{read_byte_en[0]}}
	};
endmodule
