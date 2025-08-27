`include "uvm_macros.svh"
import uvm_pkg::*;

import pc_select_pkg::*;

class pc_select_monitor extends uvm_monitor;
	`uvm_component_utils(pc_select_monitor)
	uvm_analysis_port #(pc_select_transaction) analysis_port;
	virtual pc_select_if virt_pc_select_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		analysis_port = new("analysis_port", this);

		if (!uvm_config_db#(virtual pc_select_if)::get(this, "", "virt_pc_select_if", virt_pc_select_if))
			`uvm_fatal("NOVIF", "No virtual interface set for monitor")
	endfunction

	task run_phase(uvm_phase phase);
		forever begin
			pc_select_transaction tx = pc_select_transaction#(.XLEN(32))::type_id::create("tx");;
			// no clock to sync with here

			#1

			// read the values from the virtual interface
			tx.pc_plus_four = virt_pc_select_if.pc_plus_four;
			tx.evaluated_next_instruction = virt_pc_select_if.evaluated_next_instruction;
			tx.predicted_next_instruction = virt_pc_select_if.predicted_next_instruction;
			tx.evaluated_branch_mispredicted = virt_pc_select_if.evaluated_branch_mispredicted;
			tx.predicted_branch_predicted_taken = virt_pc_select_if.predicted_branch_predicted_taken;

			// write to analysis port
			analysis_port.write(tx);
		end
	endtask
endclass
