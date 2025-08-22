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
			tx.instruction = virt_rf_wb_select_if.instruction;
			tx.rs1 = virt_rf_wb_select_if.rs1;
			tx.rs2 = virt_rf_wb_select_if.rs2;
			tx.rd = virt_rf_wb_select_if.rd;
			tx.immediate = virt_rf_wb_select_if.immediate;
			tx.op1_src = virt_rf_wb_select_if.op1_src;
			tx.op2_src = virt_rf_wb_select_if.op2_src;
			tx.rd_select = virt_rf_wb_select_if.rd_select;
			tx.alu_op = virt_rf_wb_select_if.alu_op;
			tx.sign = virt_rf_wb_select_if.sign;
			tx.branch = virt_rf_wb_select_if.branch;
			tx.branch_if_zero = virt_rf_wb_select_if.branch_if_zero;
			tx.jump = virt_rf_wb_select_if.jump;
			tx.branch_base = virt_rf_wb_select_if.branch_base;
			tx.rf_write_en = virt_rf_wb_select_if.rf_write_en;
			tx.mem_write_en = virt_rf_wb_select_if.mem_write_en;

			// write to analysis port
			analysis_port.write(tx);
		end
	endtask
endclass
