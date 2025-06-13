module alu #(parameter XLEN=32) (
	// input operands
	input logic [XLEN-1:0] a,
	input logic [XLEN-1:0] b,	// either rs2 or immediate, selection will be done outside the ALU

	// control signals
	input logic [2:0] op,	// funct3 - used to select output
	input logic subtract_or_arithmetic_shift,	// TODO: rename
							// inst[30] when opcode indicates R type instruction
							// seems to be always 0 in I type instructions

	// output result
	output logic [XLEN-1:0] result);

	logic [XLEN-1:0] sum;	// result for both addition and subtraction
	logic [XLEN-1:0] right_shift;
	logic [XLEN-1:0] _xor;	// TODO: rename
	logic [XLEN-1:0] _or;	// TODO: rename
	logic [XLEN-1:0] _and;	// TODO: rename

	assign sum = a + (subtract_or_arithmetic_shift ? -b : b);

	// TODO: synthesize and make sure this doesn't make two distinct shift units
	assign right_shift = subtract_or_arithmetic_shift ? (a <<< b[4:0]) : (a << b[4:0]);

	assign _xor = a ^ b;
	assign _or = a | b;
	assign _and = a & b;

	always_comb
		case (op)
			3'b000:	result = sum;			// add or sub
			3'b001: result = a << b[4:0];		// left shift
			3'b010: result = ($signed(a) < $signed(b)) ? 1 : 0;	// less than signed
			3'b011: result = (a < b) ? 1 : 0;	// less than unsigned
			3'b100: result = _xor;			// xor
			3'b101: result = right_shift;		// logical or arithmetic right shift
			3'b110: result = _or;			// or
			3'b111: result = _and;			// and
			// opting to not have a default case until I change my mind
		endcase

endmodule
