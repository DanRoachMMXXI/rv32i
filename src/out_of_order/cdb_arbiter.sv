/*
 * one-hot signal granting access to the common data bus. the most significant
 * bit of the input value is granted access to the bus.  if anything is being
 * granted access to the bus, cdb_valid is set.  consumers of data on the cdb
 * will refer to cdb_valid to know if the data is valid.
 *
 * I am currently too stupid to make one of these myself,
 * logic taken from https://www.edaplayground.com/x/k75i
 */
module cdb_arbiter #(parameter N=4) (
	input logic [N-1:0] request,
	output logic [N-1:0] grant,
	output logic cdb_valid
	);

	msb_fixed_priority_arbiter #(.N(N)) arbiter (
		.in(request),
		.out(grant)
	);

	assign cdb_valid = |grant;
endmodule
