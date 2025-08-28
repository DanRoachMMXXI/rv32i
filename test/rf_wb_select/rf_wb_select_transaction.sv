`include "uvm_macros.svh"
import uvm_pkg::*;

import opcode::*;

class rf_wb_select_transaction #(parameter XLEN=32) extends uvm_sequence_item;
	`uvm_object_utils(rf_wb_select_transaction)

    // inputs
	rand logic [XLEN-1:0] alu_result;
	rand logic [XLEN-1:0] memory_data_out;
	rand logic [XLEN-1:0] pc_plus_four;
	rand logic [1:0] select;

    // outputs
	logic [XLEN-1:0] rd;

	function new(string name = "");
		super.new(name);
	endfunction
endclass
