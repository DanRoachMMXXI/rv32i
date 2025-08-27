`include "uvm_macros.svh"
import uvm_pkg::*;

import pc_select_pkg::*;

class pc_select_scoreboard #(parameter XLEN=32) extends uvm_component;
	`uvm_component_utils(pc_select_scoreboard)

	uvm_analysis_imp #(pc_select_transaction, pc_select_scoreboard) analysis_export;
	// no need for the expected state here, it's a combinational component
	
	function new(string name, uvm_component parent);
		super.new(name, parent);
		analysis_export = new("analysis_export", this);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction

	function void write(pc_select_transaction tx);
		if (!tx.evaluated_branch_mispredicted && !tx.predicted_branch_predicted_taken && tx.pc_next != tx.pc_plus_four)
			`uvm_error("SCOREBOARD", "Neither evaluated_branch_mispredicted or predicted_branch_predicted_taken were set, but pc_next was not assigned pc_plus_four")
		if (tx.evaluated_branch_mispredicted && tx.pc_next != tx.evaluated_next_instruction)
			`uvm_error("SCOREBOARD", "The evaluated branch was mispredicted, but pc_next was not assigned evaluated_next_instruction")
		if (!tx.evaluated_branch_mispredicted && tx.predicted_branch_predicted_taken && tx.pc_next != tx.predicted_next_instruction)
			`uvm_error("SCOREBOARD", "The evaluated branch was not mispredicted and the predicted branch was predicted taken, but pc_next was not assigned predicted_next_instruction")
	endfunction
endclass
