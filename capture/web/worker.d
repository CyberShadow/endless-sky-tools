module worker;

import std.experimental.allocator;
import std.stdio;

// Build with https://github.com/CyberShadow/dscripten-tools

import core.stdc.stdio;
import core.bitop;

import ldc.arrayinit;
import dscripten.standard;
import dscripten.typeinfo;

import alloc;
import calcnp;
import common;

extern(C)
void main() @nogc
{
	Allocator allocator;
	.allocator = &allocator;

	auto problem = getProblem();
	auto result = calculate(problem);

	printf("Win odds: %f%% (1 in %d)\n", 100 * result.winOdds, cast(int)(1 / result.winOdds));
}
