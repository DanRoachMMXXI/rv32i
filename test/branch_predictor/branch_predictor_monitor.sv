`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_predictor_pkg::*;

class branch_predictor_monitor extends uvm_monitor;
	`uvm_component_utils(branch_predictor_monitor)
	uvm_analysis_port #(branch_predictor_transaction) analysis_port;
	virtual branch_predictor_if virt_branch_predictor_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		analysis_port = new("analysis_port", this);

		if (!uvm_config_db#(virtual branch_predictor_if)::get(this, "", "virt_branch_predictor_if", virt_branch_predictor_if))
			`uvm_fatal("NOVIF", "No virtual interface set for monitor")
	endfunction

	task run_phase(uvm_phase phase);
		forever begin
			branch_predictor_transaction tx = branch_predictor_transaction#(.XLEN(32))::type_id::create("tx");;
			// no clock to sync with here

			#1

			// read the vbranch_predictores from the virtual interface
			tx.instruction = virt_branch_predictor_if.instruction;
			tx.rs1 = virt_branch_predictor_if.rs1;
			tx.rs2 = virt_branch_predictor_if.rs2;
			tx.rd = virt_branch_predictor_if.rd;
			tx.immediate = virt_branch_predictor_if.immediate;
			tx.op1_src = virt_branch_predictor_if.op1_src;
			tx.op2_src = virt_branch_predictor_if.op2_src;
			tx.rd_select = virt_branch_predictor_if.rd_select;
			tx.alu_op = virt_branch_predictor_if.alu_op;
			tx.sign = virt_branch_predictor_if.sign;
			tx.branch = virt_branch_predictor_if.branch;
			tx.branch_if_zero = virt_branch_predictor_if.branch_if_zero;
			tx.jump = virt_branch_predictor_if.jump;
			tx.branch_base = virt_branch_predictor_if.branch_base;
			tx.rf_write_en = virt_branch_predictor_if.rf_write_en;
			tx.mem_write_en = virt_branch_predictor_if.mem_write_en;

			// write to analysis port
			analysis_port.write(tx);
		end
	endtask
endclass
