`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_evaluator_pkg::*;

class branch_evaluator_test extends uvm_test;
	`uvm_component_utils(branch_evaluator_test)
	branch_evaluator_env env;
	branch_evaluator_sequence seq;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env = branch_evaluator_env::type_id::create("env", this);
	endfunction

	task run_phase(uvm_phase phase);
		seq = branch_evaluator_sequence::type_id::create("seq");
		seq.start(env.agent.sequencer);
		phase.raise_objection(this);
		# 10
		phase.drop_objection(this);
	endtask
endclass
