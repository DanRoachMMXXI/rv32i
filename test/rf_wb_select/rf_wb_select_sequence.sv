`include "uvm_macros.svh"
import uvm_pkg::*;

class rf_wb_select_sequence extends uvm_sequence #(rf_wb_select_transaction);
	`uvm_object_utils(rf_wb_select_sequence)

	// needs a default name
	function new (string name = "rf_wb_select_sequence");
		super.new(name);
	endfunction

	task body;
		forever begin
			rf_wb_select_transaction tx;
			tx = rf_wb_select_transaction#(.XLEN(32))::type_id::create("tx");
			start_item(tx);		// handshake to communicate with driver
			
			// no sim license workaround
            tx.alu_result = $urandom_range(0, (1<<32)-1);
            tx.memory_data_out = $urandom_range(0, (1<<32)-1);
            tx.pc_plus_four = $urandom_range(0, (1<<32)-1);
            tx.select = $urandom_range(0, 2);

			finish_item(tx);	// send transaction to driver
			#1;
		end
	endtask
endclass
