/*
 * This module is just the reset logic for the reservation station.  It's
 * separated from the reservation station because I realized the conditions
 * that I wanted to reset the reservation station for the ALU FU and the
 * memory address FU are differet: the ALU FU stations reset when they see
 * their ROB tag on the CDB, but the memory address FU can reset once it sees
 * its address get sent to the ROB/Load buffer 
 * - the address isn't sent to the CDB, the value loaded from memory is (and
 *   stores don't put a value on the CDB)
 * - the address FU doesn't need to wait for the load or store to complete:
 *   that's handled by the ROB and Load buffer
 * - TODO: how do values get forwarded into the store entry in the ROB??
 */
module reservation_station_reset #(parameter TAG_WIDTH=32) (
	input logic global_reset,			// ACTIVE LOW
	input logic data_bus_active,
	input logic [TAG_WIDTH-1:0] data_bus_tag,
	input logic [TAG_WIDTH-1:0] rs_rob_tag,
	output logic reservation_station_reset		// ALSO ACTIVE LOW
	);

	assign reservation_station_reset = global_reset
		// have to invert the following reset logic to make it active low
		&& !(data_bus_active && data_bus_tag == rs_rob_tag);
endmodule
