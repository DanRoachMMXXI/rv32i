`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_predictor_pkg::*;

class branch_predictor_test extends uvm_test;
	`uvm_component_utils(branch_predictor_test)
	branch_predictor_env env;
	branch_predictor_sequence seq;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env = branch_predictor_env::type_id::create("env", this);
	endfunction

	task run_phase(uvm_phase phase);
		seq = branch_predictor_sequence::type_id::create("seq");
		seq.start(env.agent.sequencer);
		phase.raise_objection(this);
		# 10
		phase.drop_objection(this);
	endtask
endclass
