import std.algorithm.comparison;
import std.algorithm.iteration;
import std.algorithm.searching;
import std.exception;
import std.file;
import std.path;
import std.range.primitives;
import std.stdio;
import std.string;

import ae.utils.aa;

final class Node
{
	OrderedMap!(string, Node) children;
	alias children this;

	@property string value() const
	{
		enforce(children.length == 1, "Multiple values here");
		auto pair = children.byKeyValue.front;
		enforce(pair.value.children.length == 0);
		return pair.key;
	}
	bool isValue() const { return children.length == 1 && children.byValue.front.children.length == 0; }

	string onlyChildName() const { enforce(children.length == 1); return children.byKey.front; }
	inout(Node) onlyChild() inout { enforce(children.length == 1); return children.byValue.front; }

	inout(Node) opIndex(string s) inout { return children[s]; }
	override string toString() const { return format("%-(%s%)", children.byKeyValue.map!(kv => format("%(%s%)", [kv.key]) ~ "\n" ~ kv.value.toString().indent())); }

	void iterLeaves(void delegate(string[]) callback, string[] stack = null) const
	{
		if (!children)
			callback(stack);
		else
			foreach (name, value; children)
				value.iterLeaves(callback, stack ~ name);
	}
}

enum gameDir = "game"; // clone or create symlink as necessary

@property const(Node) gameData()
{
	static Node root;
	if (!root)
	{
		root = new Node;
		Node[] stack;
		foreach (de; dirEntries(gameDir ~ "/data", "*.txt", SpanMode.shallow))
		{
			if (de.baseName == "variants.txt")
				continue;

			scope(failure) writefln("Error reading file %s:", de.name);
			foreach (i, line; de.readText.splitLines)
			{
				auto oline = line;
				scope(failure) writefln("Error reading line %d (%(%s%)):", i+1, [oline]);
				if (line.strip.length == 0 || line[0] == '#')
					continue;
				Node n = root;
				size_t depth;
				while (line.skipOver("\t"))
					n = stack[min(depth++, $-1)]; // TODO: data bug?
				while (line.length)
				{
					auto w = readWord(line);
					while (line.skipOver(" ")) {}
					auto pNext = w in n.children;
					if (!pNext)
					{
						n.children[w] = new Node;
						pNext = w in n.children;
					}
					n = *pNext;
				}
				stack = stack[0..min(depth, $)] ~ n;
			}
		}
	}
	return root;
}

private string indent(string s)
{
	if (!s.length)
		return s;
	s = "\t" ~ s.replace("\n", "\n\t");
	if (s[$-1] == '\t')
		s = s[0..$-1];
	return s;
}

private string readWord(ref string s)
{
	while (s.skipOver(" ")) {}
	if (s[0] == '"')
	{
		auto p = s[1..$].findSplit("\"");
		s = p[2];
		return p[0];
	}
	else
	if (s[0] == '`')
	{
		auto p = s[1..$].findSplit("`");
		s = p[2];
		return p[0];
	}
	else
	{
		auto p = s.findSplit(" ");
		s = p[2];
		return p[0];
	}
}

version(test_data)
void main()
{
	writeln(gameData["ship"]["Argosy"].children.keys);
	writeln(gameData["ship"]["Argosy"]);
}
