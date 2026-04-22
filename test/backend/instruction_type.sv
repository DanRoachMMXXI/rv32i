`ifndef INSTRUCTION_TYPE_SV
`define INSTRUCTION_TYPE_SV

package instruction_type;
	logic [1:0] ALU = 2'b00;
	logic [1:0] BRANCH = 2'b01;
	logic [1:0] LOAD = 2'b10;
	logic [1:0] STORE = 2'b11;
endpackage

`endif
