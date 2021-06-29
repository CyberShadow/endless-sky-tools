import std.algorithm.comparison;
import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.exception;
import std.file;
import std.path;
import std.range.primitives;
import std.stdio;
import std.string;

import ae.utils.aa;

final class Node
{
	string[] key;
	Node[] children;
	// alias children this;

	@property string value() const { enforce(!children, "Value has children"); return key[1 .. $].sole; }
	// {
	// 	enforce(children.length == 1, "Multiple values here");
	// 	auto pair = children.byKeyValue.front;
	// 	enforce(pair.value.children.length == 0);
	// 	return pair.key;
	// }
	bool isValue() const { return children.length == 0 && key.length == 2; }

	// string onlyChildName() const { enforce(children.length == 1); return children.byKey.front; }
	// Node onlyChild() { enforce(children.length == 1); return children.byValue.front; }
	// // inout(Node) onlyChild() inout { enforce(children.length == 1); return children.byValue.front; }

	inout(Node)[] all(string[] key ...) inout
	{
		inout(Node)[] result;
		foreach (n; children)
			if (n.key == key)
				result ~= n;
		return result;
	}
	inout(Node) opIndex(string[] key ...) inout { return all(key).sole; }
	override string toString() const { return format("%-(%s%)", children.map!(c => format("%(%s%)", [c.key]) ~ "\n" ~ c.toString().indent())); }

	inout(Node)* opBinaryRight(string op : "in")(string[] key ...) inout
	{
		auto found = all(key);
		if (!found.length)
			return null;
		return &found.sole;
	}

	inout(Node)[] withPrefix(string[] key ...) inout
	{
		inout(Node)[] result;
		foreach (n; children)
			if (n.key.startsWith(key))
				result ~= n;
		return result;
	}

	void iterLeaves(void delegate(string[]) callback, string[] stack = null) const
	{
		stack ~= key;
		if (!children)
			callback(stack);
		else
			foreach (node; children)
				node.iterLeaves(callback, stack);
	}
}

ref T sole(T)(T[] items)
{
	enforce(items.length == 1, "Expected 1 %s but have %d".format(T.stringof, items.length));
	return items[0];
}

enum gameDir = "game"; // clone or create symlink as necessary

Node loadData(string[] fileNames)
{
	Node root = new Node;
	Node[] stack;
	foreach (fn; fileNames)
	{
		scope(failure) writefln("Error reading file %s:", fn);
		foreach (i, line; fn.readText.splitLines)
		{
			auto oline = line;
			scope(failure) writefln("Error reading line %d (%(%s%)):", i+1, [oline]);
			if (line.strip.length == 0 || line[0] == '#')
				continue;
			Node n = root;
			size_t depth;
			while (line.skipOver("\t"))
				n = stack[min(depth++, $-1)]; // TODO: data bug?
			auto node = new Node;
			while (line.length)
			{
				auto w = readWord(line);
				while (line.skipOver(" ")) {}
				node.key ~= w;
			}
			n.children ~= node;
			stack = stack[0..min(depth, $)] ~ node;
		}
	}
	return root;
}

@property const(Node) gameData()
{
	static Node root;
	if (!root)
		root = loadData(dirEntries(gameDir ~ "/data", "*.txt", SpanMode.depth).map!(de => de.name).array);
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
	writeln(gameData[["ship", "Argosy"]].children.map!(c => c.key));
	writeln(gameData[["ship", "Argosy"]]);
}
