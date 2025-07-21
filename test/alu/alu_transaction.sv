`include "uvm_macros.svh"
import uvm_pkg::*;

class alu_transaction #(parameter XLEN=32) extends uvm_sequence_item;
	`uvm_object_utils(alu_transaction)

	rand logic [XLEN-1:0] a;
	rand logic [XLEN-1:0] b;
	rand logic [2:0] op;
	rand logic sign;

	// outputs
	// not rand, will be set by the monitor reading the virtual if
	logic [XLEN-1:0] result;
	logic zero;

	function new(string name = "");
		super.new(name);
	endfunction
endclass
