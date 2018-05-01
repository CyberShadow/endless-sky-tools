import std.format;
import std.range;
import std.stdio;

import data;
import shipcfg;
import shipdata;

void createSave(string fn, Config[] configs)
{
	auto f = File(fn, "wb");
	f.writeln(`pilot Test Drive`);
	f.writeln(`date 17 11 3013`);
	f.writeln(`system Rutilicus`);
	f.writeln(`planet "New Boston"`);
	f.writeln(`clearance`);
	f.writeln();

	foreach (i, config; configs)
	{
		auto ship = shipData.items[config.items[0]];
		auto shipNode = gameData["ship"][ship.name];
		f.writefln("ship %(%s%)", [ship.name]);
		f.writefln("\tname %(%s%)", ["%s Test %d".format(ship.name, i+1)]);
		f.writefln("\tsystem Rutilicus");
		f.writefln("\tplanet \"New Boston\"");
		f.writefln("\tcrew %s", shipNode["attributes"]["required crew"].value);
		f.writefln("\tfuel %s", shipNode["attributes"]["fuel capacity"].value);
		f.writefln("\tshields %s", shipNode["attributes"]["shields"].value);
		f.writefln("\thull %s", shipNode["attributes"]["hull"].value);
		f.writeln();

		void dump(string name, Node node, int depth)
		{
			if (node.isValue)
				f.writefln("%s%(%s%) %(%s%)", '\t'.repeat(depth), [name], [node.value]);
			else
			if (name == "gun" || name == "engine")
			{
				void printLines(Node node, string[] stack)
				{
					if (node.isValue)
						f.writefln("%s%(%s%)%( %s%)", '\t'.repeat(depth), [name], stack ~ node.value);
					else
						foreach (childName, childNode; node.children)
							printLines(childNode, stack ~ childName);
				}
				printLines(node, null);
			}
			else
			{
				f.writefln("%s%(%s%)", '\t'.repeat(depth), [name]);
				foreach (childName, childNode; node.children)
					dump(childName, childNode, depth + 1);
			}
		}

		foreach (name, value; shipNode.children)
			if (name != "outfits")
				dump(name, value, 1);
		f.writefln("\toutfits");
		foreach (itemIndex; config.items[1..config.numItems])
			f.writefln("\t\t%(%s%)", [shipData.items[itemIndex].name]);
	}
}

version(none)
void main()
{
	auto c = Config.load("raven-v2.json");
	createSave("/dev/stdout", [c]);
}
