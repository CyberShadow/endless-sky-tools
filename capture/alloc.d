module alloc;

import std.algorithm.comparison;
import stdx.allocator.building_blocks.allocator_list;
import stdx.allocator.building_blocks.null_allocator;
import stdx.allocator.building_blocks.region;
import stdx.allocator.mallocator;

alias Allocator = AllocatorList!((n) => Region!Mallocator(max(n, 1024 * 4096)), NullAllocator);
__gshared Allocator* allocator;

version (dscripten) {} else
shared static this()
{
	allocator = new Allocator;
}
