`include "uvm_macros.svh"
import uvm_pkg::*;

class pc_select_transaction #(parameter XLEN=32) extends uvm_sequence_item;
	`uvm_object_utils(pc_select_transaction)

    // inputs
    rand logic [XLEN-1:0] pc_plus_four;
    rand logic [XLEN-1:0] evaluated_next_instruction;
    rand logic [XLEN-1:0] predicted_next_instruction;
    rand logic evaluated_branch_mispredicted;
    rand logic predicted_branch_predicted_taken;

    // outputs
    logic [XLEN-1:0] pc_next;

	function new(string name = "");
		super.new(name);
	endfunction
endclass
