`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_evaluator_pkg::*;

class branch_evaluator_scoreboard #(parameter XLEN=32) extends uvm_component;
	`uvm_component_utils(branch_evaluator_scoreboard)

	uvm_analysis_imp #(branch_evaluator_transaction, branch_evaluator_scoreboard) analysis_export;
	// no need for the expected state here, it's a combinational component
	
	function new(string name, uvm_component parent);
		super.new(name, parent);
		analysis_export = new("analysis_export", this);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction

	function void write(branch_evaluator_transaction tx);
		// writing the logic a bit differently than the exact
		// expressions used in the implementation out of principle:
		// the validation logic shouldn't be identical to the
		// implementation logic, since it could validate incorrect
		// logic.
		logic branch_taken;
		logic expected_branch_mispredicted;

		// `uvm_info("SCOREBOARD", "transaction:", UVM_NONE)
		// `uvm_info("SCOREBOARD", $sformatf("jump = %0d", tx.jump), UVM_NONE)
		// `uvm_info("SCOREBOARD", $sformatf("branch = %0d", tx.branch), UVM_NONE)
		// `uvm_info("SCOREBOARD", $sformatf("branch_if_zero = %0d", tx.branch_if_zero), UVM_NONE)
		// `uvm_info("SCOREBOARD", $sformatf("zero = %0d", tx.zero), UVM_NONE)
		// `uvm_info("SCOREBOARD", $sformatf("pc_plus_four = %0d", tx.pc_plus_four), UVM_NONE)
		// `uvm_info("SCOREBOARD", $sformatf("predicted_next_instruction = %0d", tx.predicted_next_instruction), UVM_NONE)
		// `uvm_info("SCOREBOARD", $sformatf("evaluated_branch_target = %0d", tx.evaluated_branch_target), UVM_NONE)
		// `uvm_info("SCOREBOARD", $sformatf("next_instruction = %0d", tx.next_instruction), UVM_NONE)

		if (tx.jump)
			branch_taken = 1;
		else if (tx.branch && tx.branch_if_zero == tx.zero)
			branch_taken = 1;
		else
			branch_taken = 0;

		// check next_instruction to make sure it got assigned the
		// correct address
		if (branch_taken && tx.next_instruction != tx.evaluated_branch_target)
			`uvm_error("SCOREBOARD", "branch_taken is 1, but the next_instruction was not assigned the evaluated_branch_target")
		else if (!branch_taken && tx.next_instruction != tx.pc_plus_four)
			`uvm_error("SCOREBOARD", "branch_taken is 0, but the next_instruction was not assigned pc_plus_four")

		if (tx.branch)
		begin
			if (tx.branch_mispredicted && branch_taken == tx.branch_prediction)
				`uvm_error("SCOREBOARD", "branch_mispredicted was set, but branch_taken matched the branch_prediction")
			else if (!tx.branch_mispredicted && branch_taken != tx.branch_prediction)
				`uvm_error("SCOREBOARD", "branch_mispredicted was not set, but branch_taken did not match the branch_prediction")
		end
		else if (tx.jump)
		begin
			if (tx.branch_mispredicted && tx.next_instruction == tx.predicted_next_instruction)
				`uvm_error("SCOREBOARD", "branch_mispredicted was set for a jump instruction, but the next_instruction was equal to the predicted_next_instruction")
			else if (!tx.branch_mispredicted && tx.next_instruction != tx.predicted_next_instruction)
				`uvm_error("SCOREBOARD", "branch_mispredicted was not set for a jump instruction, but the next_instruction did not match the predicted_next_instruction")
		end

	endfunction
endclass
