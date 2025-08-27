`include "uvm_macros.svh"
import uvm_pkg::*;

class pc_select_sequence extends uvm_sequence #(pc_select_transaction);
	`uvm_object_utils(pc_select_sequence)

	// needs a default name
	function new (string name = "pc_select_sequence");
		super.new(name);
	endfunction

	task body;
		forever begin
			pc_select_transaction tx;
			tx = pc_select_transaction#(.XLEN(32))::type_id::create("tx");
			start_item(tx);		// handshake to communicate with driver
			
			// no sim license workaround

            tx.pc_plus_four = $urandom_range(0, (1<<XLEN)-1);
            tx.evaluated_next_instruction = $urandom_range(0, (1<<XLEN)-1);
            tx.predicted_next_instruction = $urandom_range(0, (1<<XLEN)-1);
            tx.evaluated_branch_mispredicted = $urandom_range(0, 1);
            tx.predicted_branch_predicted_taken = $urandom_range(0, 1);

			finish_item(tx);	// send transaction to driver
			#1;
		end
	endtask
endclass
