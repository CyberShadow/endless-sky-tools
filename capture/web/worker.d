module worker;

import std.experimental.allocator;
import std.stdio;

// Build with https://github.com/CyberShadow/dscripten-tools

import core.stdc.stdio;
import core.bitop;
import core.checkedint;
import core.stdc.stdlib;

import ldc.arrayinit;
import dscripten.standard;
import rt.lifetime;
import dscripten.typeinfo;
//import rt.dmain2;
import rt.invariant_;

import alloc;
import calcnp;
import common;

extern(C)
	void main() //@nogc
{
	//gc_init();
	/*
	while (true)
	{
		printf("----------------------------\n");
		Allocator0s allocator0s;
		.allocator0s = &allocator0s;

		Allocator allocator;
		.allocator = &allocator;

		auto p = make!int(allocator);
		printf("%p\n", p);

		allocator0s.reportStatistics(std.stdio.stdout);

		auto problem = getProblem();
		p = make!int(allocator); printf("%p\n", p);
		auto result = calculate(problem);

		printf("Win odds: %f%% (1 in %d)\n", 100 * result.winOdds, cast(int)(1 / result.winOdds));

		p = make!int(allocator); printf("%p\n", p);

		//printf("%d\n", allocator.deallocateAll());

	}
	*/

	/*
	while (true)
	{
		printf("----------------------------\n");
		static __gshared Allocator0s allocator0s;
		allocator0s = Allocator0s.init;

		.allocator0s = &allocator0s;

		Allocator allocator;
		.allocator = &allocator;

		auto p = make!int(allocator);
		printf("%p\n", p);

        printf("StatsCollector[%p].reportStatistics\n", &allocator0s);
		allocator0s.reportStatistics(std.stdio.stdout);
		printf("%d\n", allocator.deallocateAll());
	}
	*/
	allocTest();
}
