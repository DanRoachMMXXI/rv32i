`include "uvm_macros.svh"
import uvm_pkg::*;

import pc_select_pkg::*;

class pc_select_env extends uvm_env;
	`uvm_component_utils(pc_select_env)

	pc_select_agent agent;
	pc_select_scoreboard scoreboard;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		agent = pc_select_agent::type_id::create("agent", this);
		scoreboard = pc_select_scoreboard#(.XLEN(32))::type_id::create("scoreboard", this);
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		agent.monitor.analysis_port.connect(scoreboard.analysis_export);
	endfunction

	task run_phase(uvm_phase phase);
		// talked with ChatGPT to better understand this
		// objections can be raised in the environment and the test,
		// as well as other components too.  Simple tests can manage
		// objections at the test level, but more complicated systems
		// will benefit from having their objections managed in the
		// environment.  I'm just leaving an objection here to work
		// from in future test setups.
		phase.raise_objection(this);
		# 100
		phase.drop_objection(this);
	endtask
endclass
