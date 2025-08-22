`include "uvm_macros.svh"
import uvm_pkg::*;

import opcode::*;

class branch_predictor_sequence extends uvm_sequence #(branch_predictor_transaction);
	`uvm_object_utils(branch_predictor_sequence)

	// needs a default name
	function new (string name = "branch_predictor_sequence");
		super.new(name);
	endfunction

	task body;
		forever begin
			branch_predictor_transaction tx;
			tx = branch_predictor_transaction#(.XLEN(32))::type_id::create("tx");
			start_item(tx);		// handshake to communicate with driver
			
			// no sim license workaround

			// select a random opcode
			tx.instruction[6:0] = opcodes[$urandom_range(0, opcodes.size-1)];
			`uvm_info("SEQUENCE", $sformatf("Selected opcode b%0b", tx.instruction[6:0]), UVM_NONE)
			
			// build out a legal instruction based on the opcode
			case (tx.instruction[6:0])
				R_TYPE:
				begin
					tx.instruction[11:7] = $urandom_range(0, 31);	// rd
					tx.instruction[19:15] = $urandom_range(0, 31);	// rs1
					tx.instruction[24:20] = $urandom_range(0, 31);	// rs2
					tx.instruction[14:12] = $urandom_range(0, 7);	// funct3

					tx.instruction[31:25] = 7'b0000000;	// funct7
					if (tx.instruction[14:12] inside {3'b000, 3'b101})
						tx.instruction[30] = $urandom_range(0, 1);
				end
				I_TYPE_ALU,
				I_TYPE_LOAD,
				I_TYPE_JALR: begin
					tx.instruction[11:7] = $urandom_range(0, 31);	// rd
					tx.instruction[19:15] = $urandom_range(0, 31);	// rs1
					tx.instruction[14:12] = $urandom_range(0, 7);	// funct3

					tx.instruction[31:20] = $urandom_range(0, (1<<12)-1);	// immediate
				end
				B_TYPE: begin
					const logic[2:0] valid_functs[] = '{
						3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111
					};

					tx.instruction[19:15] = $urandom_range(0, 31);	// rs1
					tx.instruction[24:20] = $urandom_range(0, 31);	// rs2
					tx.instruction[14:12] = valid_functs[$urandom_range(0, valid_functs.size-1)];	// funct3
					{
						tx.instruction[31],
						tx.instruction[7],
						tx.instruction[30:25],
						tx.instruction[11:8]
					} = $urandom_range(0, (1<<13)-1);	// 13 bit immediate
				end
				S_TYPE: begin
					tx.instruction[19:15] = $urandom_range(0, 31);	// rs1
					tx.instruction[24:20] = $urandom_range(0, 31);	// rs2

					{
						tx.instruction[31:25],
						tx.instruction[11:7]
					} = $urandom_range(0, (1<<12)-1);	// immediate
				end
				JAL,
				LUI,
				AUIPC: begin
					tx.instruction[11:7] = $urandom_range(0, 31);	// rd
					tx.instruction[31:12] = $urandom_range(0, (1<<20)-1);	// 20 bit immediate
				end
				default: begin
					`uvm_error("SEQUENCE", $sformatf("ERROR constructing instruction from opcode 0x%0h", tx.instruction[6:0]))
				end
			endcase

			finish_item(tx);	// send transaction to driver
			#1;
		end
	endtask
endclass
