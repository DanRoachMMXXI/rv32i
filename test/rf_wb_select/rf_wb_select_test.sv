`include "uvm_macros.svh"
import uvm_pkg::*;

import rf_wb_select_pkg::*;

class rf_wb_select_test extends uvm_test;
	`uvm_component_utils(rf_wb_select_test)
	rf_wb_select_env env;
	rf_wb_select_sequence seq;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env = rf_wb_select_env::type_id::create("env", this);
	endfunction

	task run_phase(uvm_phase phase);
		seq = rf_wb_select_sequence::type_id::create("seq");
		seq.start(env.agent.sequencer);
		phase.raise_objection(this);
		# 10
		phase.drop_objection(this);
	endtask
endclass
