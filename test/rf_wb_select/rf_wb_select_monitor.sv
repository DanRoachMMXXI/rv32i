`include "uvm_macros.svh"
import uvm_pkg::*;

import rf_wb_select_pkg::*;

class rf_wb_select_monitor extends uvm_monitor;
	`uvm_component_utils(rf_wb_select_monitor)
	uvm_analysis_port #(rf_wb_select_transaction) analysis_port;
	virtual rf_wb_select_if virt_rf_wb_select_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		analysis_port = new("analysis_port", this);

		if (!uvm_config_db#(virtual rf_wb_select_if)::get(this, "", "virt_rf_wb_select_if", virt_rf_wb_select_if))
			`uvm_fatal("NOVIF", "No virtual interface set for monitor")
	endfunction

	task run_phase(uvm_phase phase);
		forever begin
			rf_wb_select_transaction tx = rf_wb_select_transaction#(.XLEN(32))::type_id::create("tx");;
			// no clock to sync with here

			#1

			// read the vrf_wb_selectes from the virtual interface
			tx.alu_result = virt_rf_wb_select_if.alu_result;
            tx.memory_data_out = virt_rf_wb_select_if.memory_data_out;
            tx.pc_plus_four = virt_rf_wb_select_if.pc_plus_four;
            tx.select = virt_rf_wb_select_if.select;
            tx.rd = virt_rf_wb_select_if.rd;

			// write to analysis port
			analysis_port.write(tx);
		end
	endtask
endclass
