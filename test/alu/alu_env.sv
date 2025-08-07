`include "uvm_macros.svh"
import uvm_pkg::*;

`include "alu_agent.sv"
`include "alu_scoreboard.sv"
import alu_pkg::*;

class alu_env extends uvm_env;
	`uvm_component_utils(alu_env)

	alu_agent agent;
	alu_scoreboard scoreboard;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		agent = alu_agent::type_id::create("agent", this);
		scoreboard = alu_scoreboard::type_id::create("scoreboard", this);
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
