import std.random;
import std.stdio;

import shipcfg;

void main(string[] args)
{
	foreach (fn; args[1..$])
	{
		auto config = Config.load(fn);
		printConfig(config);
	}
}
