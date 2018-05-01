import std.algorithm.searching;
import std.array;
import std.conv;
import std.exception;
import std.stdio;
import std.string;

import ae.utils.meta;
import ae.utils.text;

import data;
import org;

enum Attribute
{
	cost,
	mass,
	drag,
	bunks,
	cargoSpace,
	outfitSpace,
	weaponCapacity,
	engineCapacity,
	heatDissipation,
	thrust,
	thrustingEnergy,
	thrustingHeat,
	turn,
	turningEnergy,
	turningHeat,
	energyCapacity,
	energyGeneration,
	heatGeneration,
	cooling,
	coolingInefficiency,
	gunPorts,
	turretMounts,
	hyperdrive,
	firingEnergy,
	firingHeat,
	shieldDamage,
//	hullDamage,

//	hull,
//	hullRepairRate,
//	hullEnergy,
//	hullHeat,

//	shield,
	shieldGeneration,
	shieldEnergy,
	shieldHeat, // heat per unit of shields repaired

}

enum fractionalMultiplier = 100;

bool isFractional(Attribute attr)
{
	switch (attr)
	{
		case Attribute.drag:
		case Attribute.heatDissipation:
		case Attribute.thrust:
		case Attribute.thrustingEnergy:
		case Attribute.thrustingHeat:
		case Attribute.turn:
		case Attribute.turningEnergy:
		case Attribute.turningHeat:
		case Attribute.energyGeneration:
		case Attribute.heatGeneration:
		case Attribute.cooling:
		case Attribute.firingEnergy:
		case Attribute.firingHeat:
		case Attribute.shieldDamage:
		case Attribute.shieldGeneration:
		case Attribute.shieldEnergy:
			return true;
		default:
			return false;
	}
}

immutable int[enumLength!Attribute] attributeMultiplier = ()
{
	int[] arr;
	foreach (e; RangeTuple!(enumLength!Attribute))
		arr ~= isFractional(cast(Attribute)e) ? fractionalMultiplier : 1;
	return arr;
}();

immutable string[enumLength!Attribute] attributeNames = ()
{
	string[] arr;
	foreach (e; RangeTuple!(enumLength!Attribute))
		arr ~= __traits(allMembers, Attribute)[e].splitByCamelCase.join(" ").toLower;
	return arr;
}();

private int parseFrac(string s)
{
	auto parts = s.findSplit(".");
	auto intPart = parts[0];
	int sign = intPart.skipOver("-") ? -1 : 1;
	if (!intPart.length)
		intPart = "0";
	auto fracPart = parts[2];
	enforce(fracPart.length <= 2, "Too little precision: " ~ s);
	while (fracPart.length < 2) fracPart ~= "0";
	return (intPart.to!int * fractionalMultiplier + fracPart.to!int) * sign;
}

struct Item
{
	string name;
	int[enumLength!Attribute] attributes;

	void fromAttributes(Node node)
	{
		foreach (Attribute attr; Attribute.init .. enumLength!Attribute)
		{
			auto name = attributeNames[attr];
			auto pNode = name in node;
			if (pNode)
			{
				auto value = (*pNode).value;
				scope(failure) writefln("Error parsing attribute %(%s%) with value %(%s%)", [name], [value]);
				if (isFractional(attr))
					attributes[attr] = value.parseFrac;
				else
					attributes[attr] = value.to!int;
			}
		}
	}
}

struct ShipData
{
	Item[] items;
	uint numShips;
}

ShipData getShipData()
{
	ShipData result;
	foreach (name, node; gameData["ship"])
	{
		if (name !in knownItems) continue;
		auto item = Item(name);
		item.fromAttributes(node["attributes"]);
		if (auto pNode = "gun" in node)
			item.attributes[Attribute.gunPorts] = pNode.children.length.to!int;
		if (auto pNode = "turret" in node)
			item.attributes[Attribute.turretMounts] = pNode.children.length.to!int;
		result.items ~= item;
	}
	result.numShips = result.items.length.to!uint;

	foreach (name, node; gameData["outfit"])
	{
		scope(failure) writefln("Error parsing outfit %(%s%):", [name]);
		if (name !in knownItems) continue;
		if (node["category"].value == "Hand to Hand") continue;
		auto item = Item(name);
		item.fromAttributes(node);
		if (auto pWeapon = "weapon" in node)
		{
			if ("ammo" in *pWeapon)
				continue; // TODO: tons / cost of ammo per unit of time / damage?
			if (auto pVelocity = "velocity" in *pWeapon)
				if (pVelocity.value.to!float < 100)
					continue; // TODO
			if (auto pReload = "reload" in *pWeapon)
			{
				if (auto pSD = "shield damage" in *pWeapon)
					item.attributes[Attribute.shieldDamage] = (pSD.value.to!float / pReload.value.to!float * 100).to!int;
				if (auto pFE = "firing energy" in *pWeapon)
					item.attributes[Attribute.firingEnergy] = (pFE.value.to!float / pReload.value.to!float * 100).to!int;
				if (auto pFE = "firing heat" in *pWeapon)
					item.attributes[Attribute.firingHeat  ] = (pFE.value.to!float / pReload.value.to!float * 100).to!int;
			}
		}
		result.items ~= item;
	}
	return result;
}
