import std.algorithm.iteration;
import std.exception;
import std.format;
import std.range;
import std.stdio;

import ae.utils.array;

import data;
import shipcfg;
import shipdata;

void createSave(string fn, Config[] configs)
{
	enum system = "Rutilicus";
	enum planet = "New Boston";

	auto f = File(fn, "wb");
	f.writefln(`pilot Test Drive`);
	f.writefln(`date 17 11 3013`);
	f.writefln(`system %s`, system.quote);
	f.writefln(`planet %s`, planet.quote);
	f.writefln(`clearance`);
	f.writeln();

	foreach (i, config; configs)
	{
		auto ship = shipData.items[config.items[0]];
		auto shipNode = gameData["ship"][ship.name];
		f.writefln("ship %s", ship.name.quote);
		f.writefln("\tname %s", "%s Test %d".format(ship.name, i+1).quote);
		f.writefln("\tsystem %s", system.quote);
		f.writefln("\tplanet %s", planet.quote);
		f.writefln("\tcrew %s", shipNode["attributes"]["required crew"].value);
		f.writefln("\tfuel %s", shipNode["attributes"]["fuel capacity"].value);
		f.writefln("\tshields %s", shipNode["attributes"]["shields"].value);
		f.writefln("\thull %s", shipNode["attributes"]["hull"].value);
		f.writeln();

		auto outfits = config.items[1..config.numItems].map!(itemIndex => shipData.items[itemIndex]);
		auto guns = outfits.filter!(item => item.attributes[Attribute.gunPorts] < 0).array;
		auto turrets = outfits.filter!(item => item.attributes[Attribute.turretMounts] < 0).array;

		void dump(string name, Node node, int depth)
		{
			if (node.isValue)
				f.writefln("%s%s %s", '\t'.repeat(depth), name.quote, node.value.quote);
			else
			if (name == "gun" || name == "engine" || name == "turret")
			{
				node.iterLeaves(
					(string[] path)
					{
						if (name == "gun")
							path = path[0..2] ~ (guns.length ? [guns.shift.name] : []);
						else
						if (name == "turret")
							path = path[0..2] ~ (turrets.length ? [turrets.shift.name] : []);
						f.writefln("%s%s%-( %s%)", '\t'.repeat(depth), name.quote, path.map!quote);
					});
			}
			else
			{
				f.writefln("%s%s", '\t'.repeat(depth), name.quote);
				foreach (childName, childNode; node.children)
					dump(childName, childNode, depth + 1);
			}
		}

		foreach (name, value; shipNode.children)
			if (name != "outfits")
				dump(name, value, 1);
		f.writefln("\toutfits");
		foreach (item; outfits)
			f.writefln("\t\t%s", item.name.quote);
	}
}

string quote(string s)
{
	if (s.contains('"'))
	{
		enforce(!s.contains('`'));
		return '`' ~ s ~ '`';
	}
	else
	if (s.contains(' '))
		return '"' ~ s ~ '"';
	else
		return s;
}

version(none)
void main()
{
	auto c = Config.load("raven-v2.json");
	createSave("/dev/stdout", [c]);
}
