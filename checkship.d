import std.random;
import std.stdio;

import shipcfg;

void main(string[] args)
{
	auto config = Config.load(args[1]);
	printConfig(config);
}
