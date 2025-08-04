/*
 * 32-bit byte-accessible memory
 *
 * This is currently being used for both instruction memory and data memory.
 * In the future, the restrictions defined in the ISA are going to need to be
 * added for the data memory, but not for the instruction memory, likely
 * leading to me splitting them into two distinct modules.
 *
 * It then comes as no surprise that this doesn't throw faults on accessing
 * address 0, byte-misaligned reads and writes, and other faults the ISA might
 * specify.
 */
module memory #(
	parameter MEM_SIZE=4096,
	parameter MEM_FILE = "") (
	input logic clk,
	input logic reset,	// active low reset
	
	// TODO: make this safe and synthesizeable
	// I've already tried using the width of this address as a parameter
	// to this module, but that caused issues when computing the size of
	// the memory by defaulting to 32 bits (range 0:0xFFFFFFFF is 0:-1)
	//
	// If I give up on synthesizability, I can just use $clog2
	input logic [31:0] address,
	input logic [31:0] data_in,

	input logic [3:0] read_byte_en,	// enable each byte of the output
	input logic [3:0] write_byte_en,	// enable each byte for writes
	output logic [31:0] data_out
	);

	reg [7:0] memory [0:MEM_SIZE-1];	// 1-byte entries
	integer i;

	// This was taken from ChipVerify without the select signal
	// https://www.chipverify.com/verilog/verilog-arrays-memories
	// TODO: test
	// potential modifications:
	// - add select signal
	// - remove else block for updating memory contents
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
		end else begin
			// write bytes that are enabled
			memory[address + 3] <= (write_byte_en[3]) ? data_in[31:24] : memory[address + 3];
			memory[address + 2] <= (write_byte_en[2]) ? data_in[31:24] : memory[address + 2];
			memory[address + 1] <= (write_byte_en[1]) ? data_in[31:24] : memory[address + 1];
			memory[address + 0] <= (write_byte_en[0]) ? data_in[31:24] : memory[address + 0];
		end
	end

	// TODO maybe copy ChipVerify part
	assign data_out = {
		memory[address + 3] & {8{read_byte_en[3]}},
		memory[address + 2] & {8{read_byte_en[2]}},
		memory[address + 1] & {8{read_byte_en[1]}},
		memory[address + 0] & {8{read_byte_en[0]}}
	};
endmodule
