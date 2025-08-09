`include "uvm_macros.svh"
import uvm_pkg::*;

import instruction_decode_pkg::*;

class instruction_decode_monitor extends uvm_monitor;
	`uvm_component_utils(instruction_decode_monitor)
	uvm_analysis_port #(instruction_decode_transaction) analysis_port;
	virtual instruction_decode_if virt_instruction_decode_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		analysis_port = new("analysis_port", this);

		if (!uvm_config_db#(virtual instruction_decode_if)::get(this, "", "virt_instruction_decode_if", virt_instruction_decode_if))
			`uvm_fatal("NOVIF", "No virtual interface set for monitor")
	endfunction

	task run_phase(uvm_phase phase);
		forever begin
			instruction_decode_transaction tx = instruction_decode_transaction#(.XLEN(32))::type_id::create("tx");;
			// no clock to sync with here

			#1

			// read the vinstruction_decodees from the virtual interface
			// TODO change to instruction decode signals
			tx.a = virt_instruction_decode_if.a;
			tx.b = virt_instruction_decode_if.b;
			tx.op = virt_instruction_decode_if.op;
			tx.sign = virt_instruction_decode_if.sign;
			tx.result = virt_instruction_decode_if.result;
			tx.zero = virt_instruction_decode_if.zero;

			// write to analysis port
			analysis_port.write(tx);
		end
	endtask
endclass
