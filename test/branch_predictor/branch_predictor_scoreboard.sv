`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_predictor_pkg::*;

class branch_predictor_scoreboard #(parameter XLEN=32) extends uvm_component;
	`uvm_component_utils(branch_predictor_scoreboard)

	uvm_analysis_imp #(branch_predictor_transaction, branch_predictor_scoreboard) analysis_export;
	// no need for the expected state here, it's a combinational component
	
	function new(string name, uvm_component parent);
		super.new(name, parent);
		analysis_export = new("analysis_export", this);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction

	function void write(branch_predictor_transaction tx);
        // validate that it's always predicted for an unconditional jump
        if (tx.jump && !tx.branch_predicted_taken)
            `uvm_error("SCOREBOARD", "jump was set but branch_predicted_taken was not")

        // validate branch prediction logic
        // TODO can I decouple this test logic with the branch prediction
        // algorithm used?  i.e.: parameterize the branch_predictor component
        // by the algorithm used to predict the branch?
        if (tx.branch)
        begin
            if (tx.branch_target >= tx.pc_plus_four && tx.branch_predicted_taken)
                `uvm_error("SCOREBOARD", "branch was set, and branch_target  was greater than or equal to pc_plus four, and branch_predicted_taken was erroneously set")
            else if (tx.branch_target < tx.pc_plus_four && !tx.branch_predicted_taken)
                `uvm_error("SCOREBOARD", "branch was set, but branch_target was less than pc_plus_four, and branch_predicted_taken was not set")
        end

        if (!tx.jump && tx.branch && tx.branch_predicted_taken)
            `uvm_error("SCOREBOARD", "Neither jump or branch were set, but branch_predicted_taken was set")

	endfunction

endclass
