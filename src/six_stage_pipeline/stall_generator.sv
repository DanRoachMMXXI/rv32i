/*
 * Stall conditions:
 * - I_TYPE_LOAD instruction followed by an instruction that uses the loaded
 *   value from the register file.  This requires a stall because the data
 *   will not be loaded from memory until two stages ahead of where it's
 *   forwarded to the register file.
 * - I think that's it?
 *
 * A stall can only be detected as early as the decode stage, so that's where
 * it'll be done.  The behavior for a stall needs to be as follows:
 * - PC does not increment
 * - IF_ID pipeline register does not load the next instruction from ROM
 * - ID_RF pipeline register has a nop inserted
 */
module stall_generator #(parameter XLEN=32) (
	input logic [4:0] ID_rs1_index,
	input logic [4:0] ID_rs2_index,
	input logic [4:0] RF_rd_index,
	input logic [1:0] RF_rd_select,	// used to determine if the value is coming from memory
	input logic RF_rf_write_en,	// might not be needed since rd_select should only be 1 in cases where rf_write_en is 1
	output logic stall
	);
	assign stall = (RF_rd_select == 1)	// instruction in RF stage will write back from memory
		&& RF_rf_write_en		// AND instruction in RF stage does write back to the register file (likely redundant)
		&& ((RF_rd_index == ID_rs1_index) && (RF_rd_index == ID_rs2_index));	// AND matches an index of the source of the instruction in ID stage
endmodule
