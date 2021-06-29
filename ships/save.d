import std.algorithm.searching;
import std.file;
import std.stdio : stderr;
import std.string;

import ae.utils.aa;

import data;

@property const(Node) saveData()
{
	static Node root;
	if (!root)
		root = loadData(["save.txt"]);
	return root;
}

@property OrderedSet!string knownItems()
{
	static OrderedSet!string result;
	if (result)
		return result;

	OrderedSet!string planetKnown;
	foreach (name, node; saveData()["visited planet"].children)
		planetKnown.add(name);

	OrderedSet!string outfitterKnown; // outfitter categories
	foreach (planet; planetKnown.byKey)
		if (auto outfitter = gameData["planet"][planet].get("outfitter", null))
			foreach (name, node; outfitter)
				outfitterKnown.add(name);

	alias result itemKnown;
	foreach (outfitter; outfitterKnown.byKey)
			foreach (name, node; gameData["outfitter"][outfitter])
				itemKnown.add(name);

	OrderedSet!string shipyardKnown; // shipyard categories
	foreach (planet; planetKnown.byKey)
		if (auto shipyard = gameData["planet"][planet].get("shipyard", null))
			foreach (name, node; shipyard)
				shipyardKnown.add(name);

	foreach (shipyard; shipyardKnown.byKey)
			foreach (name, node; gameData["shipyard"][shipyard])
				itemKnown.add(name);

	void addFromSave(string item, string where)
	{
		if (item !in itemKnown)
		{
			stderr.writefln("Note: adding item from %s which was not found in any known outfitters/shipyards: %s", where, item);
			itemKnown.add(item);
		}
	}

	foreach (shipName, shipNode; saveData["ship"])
	{
		addFromSave(shipName, "ship");
		if (auto outfits = shipNode.get("outfits", null))
			foreach (name, node; outfits)
				addFromSave(name, "ship outfit");
	}

	foreach (line; "parts-overrides.txt".readText.splitLines)
	{
		if (!line.length || line.startsWith("#"))
			continue;
		else
		if (line.skipOver("+"))
			if (line in itemKnown)
				stderr.writeln("parts-overrides: Item already known: ", line);
			else
				itemKnown.add(line);
		else
		if (line.skipOver("-"))
			if (line !in itemKnown)
				stderr.writeln("parts-overrides: Item already \"not\" known: ", line);
			else
				itemKnown.remove(line);
		else
			stderr.writeln("parts-overrides: Unknown line: ", line);
	}

	return result;
}

// void main()
// {
// 	import std.stdio; writeln(knownItems.byKey);
// }

// "