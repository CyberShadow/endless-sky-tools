module worker;

// Build with https://github.com/CyberShadow/dscripten-tools

import dscripten.standard;
import dscripten.memory;
import dscripten.typeinfo;
//import rt.dmain2;
import rt.invariant_;

import calcnp;
import common;

extern(C)
void main()
{
	gc_init();

	import std.stdio;

	auto problem = getProblem();
	auto result = calculate(problem);

	debug(verbose)
	foreach (i, row; odds)
		writefln("%(%10g\t%)", row[]);

	writefln("Win odds: %f%% (1 in %d)", 100 * result.winOdds, cast(int)(1 / result.winOdds));
}
