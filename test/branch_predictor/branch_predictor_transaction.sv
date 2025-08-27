`include "uvm_macros.svh"
import uvm_pkg::*;

import opcode::*;

class branch_predictor_transaction #(parameter XLEN=32) extends uvm_sequence_item;
	`uvm_object_utils(branch_predictor_transaction)

    // inputs
    rand logic [XLEN-1:0] pc_plus_four;
    rand logic [XLEN-1:0] branch_target;
    rand logic jump;
    rand logic branch;

    // outputs
    logic branch_predicted_taken;

	function new(string name = "");
		super.new(name);
	endfunction
endclass
