`include "uvm_macros.svh"
import uvm_pkg::*;

import alu_pkg::*;

class alu_monitor extends uvm_monitor;
	`uvm_component_utils(alu_monitor)
	uvm_analysis_port #(alu_transaction) analysis_port;
	virtual alu_if virt_alu_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		analysis_port = new("analysis_port", this);

		if (!uvm_config_db#(virtual alu_if)::get(this, "", "virt_alu_if", virt_alu_if))
			`uvm_fatal("NOVIF", "No virtual interface set for monitor")
	endfunction

	task run_phase(uvm_phase phase);
		forever begin
			alu_transaction tx = alu_transaction#(.XLEN(32))::type_id::create("tx");;
			// no clock to sync with here

			#1

			// read the values from the virtual interface
			tx.a = virt_alu_if.a;
			tx.b = virt_alu_if.b;
			tx.op = virt_alu_if.op;
			tx.sign = virt_alu_if.sign;
			tx.result = virt_alu_if.result;
			tx.zero = virt_alu_if.zero;

			// write to analysis port
			analysis_port.write(tx);
		end
	endtask
endclass
