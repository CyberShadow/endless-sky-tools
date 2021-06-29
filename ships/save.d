import std.algorithm.searching;
import std.conv : text;
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
	foreach (node; saveData.withPrefix("visited planet"))
		planetKnown.add(node.key[1 .. $].sole);

	OrderedSet!string outfitterKnown; // outfitter categories
	foreach (planet; planetKnown.byKey)
		foreach (outfitter; gameData["planet", planet].withPrefix("outfitter"))
			outfitterKnown.add(outfitter.key[1 .. $].sole);

	alias result itemKnown;
	foreach (outfitter; outfitterKnown.byKey)
		foreach (node; gameData["outfitter", outfitter].children)
			itemKnown.add(node.key.sole);

	OrderedSet!string shipyardKnown; // shipyard categories
	foreach (planet; planetKnown.byKey)
		foreach (shipyard; gameData["planet", planet].withPrefix("shipyard"))
			shipyardKnown.add(shipyard.key[1 .. $].sole);

	foreach (shipyard; shipyardKnown.byKey)
		foreach (node; gameData["shipyard", shipyard].children)
			itemKnown.add(node.key.sole);

	void addFromSave(string item, string where)
	{
		if (item !in itemKnown)
		{
			stderr.writefln("Note: adding item from %s which was not found in any known outfitters/shipyards: %s", where, item);
			itemKnown.add(item);
		}
	}

	foreach (ship; saveData.withPrefix("ship"))
	{
		addFromSave(ship.key[1 .. $].sole, "ship");
		foreach (outfit; ship.withPrefix("outfits"))
			addFromSave(outfit.key.sole, "ship outfit");
	}

	foreach (storage; saveData.all("storage"))
		foreach (storageLocation; storage.children)
			if (storageLocation.key.startsWith("planet"))
				foreach (storageKind; storageLocation.children)
					if (storageKind.key == ["cargo"])
						foreach (itemKind; storageKind.children)
							if (itemKind.key == ["outfits"])
								foreach (outfit; itemKind.children)
									addFromSave(outfit.key[0], "planetary storage outfit"); // key[1] is count
							else
								stderr.writeln("Unknown storage item kind: " ~ itemKind.key.text);
						else
							stderr.writeln("Unknown storage kind: " ~ storageKind.key.text);
			else
				stderr.writeln("Unknown storage location: " ~ storageLocation.key.text);

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

version (main_save)
void main()
{
	import std.stdio; writeln(knownItems.byKey);
}

// "