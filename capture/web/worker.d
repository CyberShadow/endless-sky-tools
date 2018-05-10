module worker;

// Build with https://github.com/CyberShadow/dscripten-tools

import core.stdc.stdio;
import core.bitop;
import core.checkedint;

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
void main() @nogc
{
	//gc_init();

	Allocator allocator;
	.allocator = &allocator;

	auto problem = getProblem();
	auto result = calculate(problem);

	printf("Win odds: %f%% (1 in %d)\n", 100 * result.winOdds, cast(int)(1 / result.winOdds));
}
