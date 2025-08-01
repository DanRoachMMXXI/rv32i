`include "uvm_macros.svh"
import uvm_pkg::*;

`include "alu_env.sv"
import alu_pkg::*;

class alu_test extends uvm_test;
	`uvm_component_utils(alu_test)
	alu_env env;
	alu_sequence seq;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env = alu_env::type_id::create("env", this);
	endfunction

	task run_phase(uvm_phase phase);
		seq = alu_sequence::type_id::create("seq");
		seq.start(env.agent.sequencer);
		phase.raise_objection(this);
		# 10
		phase.drop_objection(this);
	endtask
endclass
