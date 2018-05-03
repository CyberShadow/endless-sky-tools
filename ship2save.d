import std.algorithm.iteration;
import std.array;
import std.stdio;

import savewriter;
import shipcfg;

void main(string[] args)
{
	createSave(`saves/ship2save.txt`, args[1..$].map!(Config.load).array);
}
