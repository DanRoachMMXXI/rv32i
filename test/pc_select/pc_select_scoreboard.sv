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
        // TODO
	endfunction
endclass
