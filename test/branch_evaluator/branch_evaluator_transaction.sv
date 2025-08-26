`include "uvm_macros.svh"
import uvm_pkg::*;

class branch_evaluator_transaction #(parameter XLEN=32) extends uvm_sequence_item;
	`uvm_object_utils(branch_evaluator_transaction)

	// inputs
	rand logic [XLEN-1:0] pc_plus_four;
	rand logic [XLEN-1:0] predicted_next_instruction;
	rand logic [XLEN-1:0] evaluated_branch_target;

	rand logic jump;
	rand logic branch;
	rand logic branch_if_zero;
	rand logic zero;
	rand logic branch_prediction;

	// omitting the constraints for now, since I don't have a license that
	// allows me to use randomize().  the constraint logic will just be
	// placed in the sequencer

	// outputs
	logic [XLEN-1:0] next_instruction;
	logic branch_mispredicted;

	function new(string name = "");
		super.new(name);
	endfunction
endclass
