import std.algorithm.searching;
import std.file;
import std.string;

void[0][string] knownItems()
{
	void[0][string] result;
	if (!result)
	{
		foreach (line; readText("docs/endless-sky.org").splitLines)
			if (line.startsWith("|"))
				result[line[1..$].findSplit("|")[0].strip] = [];
	}
	return result;
}
