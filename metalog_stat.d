import std.algorithm.searching;
import std.conv;
import std.file;
import std.stdio;
import std.string;

void main(string[] args)
{
	enum limit = 27_000_000;
	foreach (de; dirEntries(".", "metalog*.txt", SpanMode.shallow))
	{
		int numLines, numOver;
		long totalTime;
		foreach (line; de.readText.splitLines)
		{
			auto p = line.findSplit("\t");
			auto time = p[0].to!long;
			auto score = p[2].to!long;
			if (score > limit)
				numOver++;
			numLines++;
			totalTime += time;
		}
		auto avgTime = totalTime / numLines;
		writefln("%3.2f%%\t%d\t%1.4f\t%s", 100.0 * numOver / numLines, avgTime, 10000000.0 * numOver / numLines / avgTime, de.name);
	}
}
