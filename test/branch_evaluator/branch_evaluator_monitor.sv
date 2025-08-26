`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_evaluator_pkg::*;

class branch_evaluator_monitor extends uvm_monitor;
	`uvm_component_utils(branch_evaluator_monitor)
	uvm_analysis_port #(branch_evaluator_transaction) analysis_port;
	virtual branch_evaluator_if virt_branch_evaluator_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		analysis_port = new("analysis_port", this);

		if (!uvm_config_db#(virtual branch_evaluator_if)::get(this, "", "virt_branch_evaluator_if", virt_branch_evaluator_if))
			`uvm_fatal("NOVIF", "No virtual interface set for monitor")
	endfunction

	task run_phase(uvm_phase phase);
		forever begin
			branch_evaluator_transaction tx = branch_evaluator_transaction#(.XLEN(32))::type_id::create("tx");
			// no clock to sync with here

			#1

			// read the values from the virtual interface
			tx.pc_plus_four = virt_branch_evaluator_if.pc_plus_four;
			tx.predicted_next_instruction = virt_branch_evaluator_if.predicted_next_instruction;
			tx.evaluated_branch_target = virt_branch_evaluator_if.evaluated_branch_target;

			tx.jump = virt_branch_evaluator_if.jump;
			tx.branch = virt_branch_evaluator_if.branch;
			tx.branch_if_zero = virt_branch_evaluator_if.branch_if_zero;
			tx.zero = virt_branch_evaluator_if.zero;
			tx.branch_prediction = virt_branch_evaluator_if.branch_prediction;

			tx.next_instruction = virt_branch_evaluator_if.next_instruction;
			tx.branch_mispredicted = virt_branch_evaluator_if.branch_mispredicted;

			// write to analysis port
			analysis_port.write(tx);
		end
	endtask
endclass
