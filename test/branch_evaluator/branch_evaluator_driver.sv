`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_evaluator_pkg::*;

class branch_evaluator_driver extends uvm_driver #(branch_evaluator_transaction);
	`uvm_component_utils(branch_evaluator_driver)
	virtual branch_evaluator_if virt_branch_evaluator_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// get the virtual interface from top level testbench
		if (!uvm_config_db#(virtual branch_evaluator_if)::get(this, "", "virt_branch_evaluator_if", virt_branch_evaluator_if))
			`uvm_fatal("NOVIF", "No virtual interface specified for driver")
	endfunction

	task run_phase(uvm_phase phase);
		branch_evaluator_transaction tx;
		
		// begin chatgpt format of driver
		forever begin
			seq_item_port.get_next_item(tx);

			// set the inputs of the interface from the transaction
			virt_branch_evaluator_if.pc_plus_four = tx.pc_plus_four;
			virt_branch_evaluator_if.predicted_next_instruction = tx.predicted_next_instruction;
			virt_branch_evaluator_if.evaluated_branch_target = tx.evaluated_branch_target;

			virt_branch_evaluator_if.jump = tx.jump;
			virt_branch_evaluator_if.branch = tx.branch;
			virt_branch_evaluator_if.branch_if_zero = tx.branch_if_zero;
			virt_branch_evaluator_if.zero = tx.zero;
			virt_branch_evaluator_if.branch_prediction = tx.branch_prediction;
			# 1

			seq_item_port.item_done();
		end
	endtask
endclass
