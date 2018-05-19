module alloc;

import std.algorithm.comparison;
import stdx.allocator.building_blocks.stats_collector;
import std.experimental.allocator.common;
import stdx.allocator.building_blocks.allocator_list;
import stdx.allocator.building_blocks.null_allocator;
import stdx.allocator.building_blocks.region;
import stdx.allocator.mallocator;

alias OSAllocator = Mallocator;

version (all)
	alias BaseAllocator = OSAllocator;
else
{
	alias StatsAllocator = StatsCollector!(Allocator0, Options.all);
	__gshared StatsAllocator* statsAllocator;

	struct GlobalStatsAllocator { alias statsAllocator instance; alias instance this; }
	alias BaseAllocator = GlobalStatsAllocator;
}

alias RegionAllocator = Region!BaseAllocator;
//alias Allocator = AllocatorList!((n) => RegionAllocator(max(n, 1024 * 4096)), BaseAllocator);
alias Allocator = AllocatorList!((n) {
		import core.stdc.stdio;
        printf("alloc: AllocatorList requested %d bytes\n", cast(int)n);
		n += 16;
		auto r = RegionAllocator(max(n, 1024 * 4096));
		r.allocate(1);
		return r;
	}, BaseAllocator);
__gshared Allocator* allocator;

version (dscripten) {} else
shared static this() { 	allocator = new Allocator; }
