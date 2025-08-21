`include "uvm_macros.svh"
import uvm_pkg::*;

import alu_operand_select_pkg::*;

class alu_operand_select_scoreboard #(parameter XLEN=32) extends uvm_component;
	`uvm_component_utils(alu_operand_select_scoreboard)

	uvm_analysis_imp #(alu_operand_select_transaction, alu_operand_select_scoreboard) analysis_export;
	// no need for the expected state here, it's a combinational component
	
	function new(string name, uvm_component parent);
		super.new(name, parent);
		analysis_export = new("analysis_export", this);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction

	function void write(alu_operand_select_transaction tx);
		if (tx.alu_op1_src == 0 && tx.alu_op1 != tx.rs1)
			`uvm_error("SCOREBOARD", $sformatf("alu_op1_src did not select rs1 with alu_op1_src = 0"))
		else if (tx.alu_op1_src == 1 && tx.alu_op1 != tx.pc)
			`uvm_error("SCOREBOARD", $sformatf("alu_op1_src did not select pc with alu_op1_src = 1"))
		else if (tx.alu_op1_src == 2 && tx.alu_op1 != 0)
			`uvm_error("SCOREBOARD", $sformatf("alu_op1_src did not select 0 with alu_op1_src = 2"))

		if (tx.alu_op2_src == 0 && tx.alu_op2 != tx.rs2)
			`uvm_error("SCOREBOARD", $sformatf("alu_op2_src did not select rs2 with alu_op1_src = 0"))
		else if (tx.alu_op2_src == 1 && tx.alu_op2 != tx.immediate)
			`uvm_error("SCOREBOARD", $sformatf("alu_op2_src did not select immediate with alu_op1_src = 1"))
	endfunction
endclass
