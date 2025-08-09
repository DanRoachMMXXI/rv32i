`include "uvm_macros.svh"
import uvm_pkg::*;

import instruction_decode_pkg::*;

class instruction_decode_test extends uvm_test;
	`uvm_component_utils(instruction_decode_test)
	instruction_decode_env env;
	instruction_decode_sequence seq;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env = instruction_decode_env::type_id::create("env", this);
	endfunction

	task run_phase(uvm_phase phase);
		seq = instruction_decode_sequence::type_id::create("seq");
		seq.start(env.agent.sequencer);
		phase.raise_objection(this);
		# 10
		phase.drop_objection(this);
	endtask
endclass
