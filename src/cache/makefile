VERILATOR = verilator --binary -j 0

cache_block_write cbw:
	$(VERILATOR) test/cache/block_write.sv src/cache/block_write.sv

cache_mshr mshr:
	$(VERILATOR) --top-module test_mshr test/cache/mshr.sv src/common/fixed_priority_arbiter.sv src/cache/mshr.sv

lru:
	$(VERILATOR) --top-module test_lru_eviction test/cache/lru_eviction.sv src/common/lsb_priority_encoder.sv src/cache/lru_eviction.sv
