import std.algorithm.comparison;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.exception;
import std.stdio;
import std.string;

import ae.utils.array;
import ae.utils.meta;
import ae.utils.text;

import data;
import decimal;
import save;

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
	energyConsumption,
	heatGeneration,
	cooling,
	activeCooling,
	coolingInefficiency,
	gunPorts,
	turretMounts,
	hyperdrive,
//	ramscoop,
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

	antiMissile,
}

immutable string[enumLength!Attribute] attributeNames = ()
{
	string[] arr;
	foreach (e; RangeTuple!(enumLength!Attribute))
		arr ~= __traits(allMembers, Attribute)[e].splitByCamelCase.join(" ").toLower;
	arr[Attribute.antiMissile] = "anti-missile";
	return arr;
}();

alias Value = Decimal!3;

struct Item
{
	Value[enumLength!Attribute] attributes;
	string name, category;
	Value weaponVelocity;

	void fromAttributes(in Node node)
	{
		foreach (child; node.children)
			foreach (Attribute attr; Attribute.init .. enumLength!Attribute)
				if (child.key[0] == attributeNames[attr])
				{
					auto value = child.key[1 .. $].sole;
					scope(failure) writefln("Error parsing attribute %(%s%) with value %(%s%)", [name], [value]);
					attributes[attr] = value.strip;
				}
	}
}

struct ShipData
{
	Item[] items;
	uint numShips;
}

ShipData getShipData(bool all = false)
{
	//all = true;
	ShipData result;
	foreach (node; gameData.withPrefix("ship"))
	{
		scope(failure) stderr.writeln("Error with ship: " ~ node.key.text);
		if (node.key.length > 2)
			continue; // variant
		auto name = node.key[1];
		if (!all && name !in knownItems) continue;
		Item item;
		item.name = name;
		item.fromAttributes(node["attributes"]);
		item.attributes[Attribute.gunPorts] = node.withPrefix("gun").length;
		item.attributes[Attribute.turretMounts] = node.withPrefix("turret").length;
		result.items ~= item;
	}
	result.numShips = result.items.length.to!uint;

outfit:
	foreach (node; gameData.withPrefix("outfit"))
	{
		scope(failure) writefln("Error parsing outfit %(%s%):", node.key);
		auto name = node.key[1 .. $].sole;
		if (!all && name !in knownItems) continue;
		Item item;
		item.name = name;
		item.fromAttributes(node);
		foreach (category; node.withPrefix("category"))
		{
			if (category.value.isOneOf("Hand to Hand", "Ammunition", "Special"))
				continue outfit;
			item.category = category.value;
		}
		foreach (installable; node.withPrefix("installable"))
			if (installable.key[1 .. $].sole.Value < 0)
				continue outfit;
		foreach (weapon; node.all("weapon"))
		{
			if ("ammo" in weapon)
				continue; // TODO: tons / cost of ammo per unit of time / damage?
			if (auto pVelocity = "velocity" in weapon)
				item.weaponVelocity = Value(pVelocity.value);
			foreach (attribute; [Attribute.antiMissile])
				if (auto pValue = attributeNames[attribute] in weapon)
					item.attributes[attribute] += Value((*pValue).value.strip);

			// Estimate effective DPS accounting for accuracy and projectile travel time
			Value accMultiplier = 1;
			if (auto pStr = "inaccuracy" in weapon)
				accMultiplier = (100 - min(Value(100), Value(pStr.value) * 4)) / 100;
			auto travelTime = 1 / max(Value(1), item.weaponVelocity * 3 / 2);
			auto speedMultiplier = 1 - travelTime;

			auto projMultiplier = accMultiplier * speedMultiplier;
			debug(weapon_multiplier) writefln("%s\t%s\t%s\t%s", accMultiplier, speedMultiplier, projMultiplier, name);

			if (auto pReload = "reload" in weapon)
			{
				if (auto pSD = "shield damage" in weapon)
					item.attributes[Attribute.shieldDamage] = Value(pSD.value) / Value(pReload.value) * projMultiplier;
				if (auto pFE = "firing energy" in weapon)
					item.attributes[Attribute.firingEnergy] = Value(pFE.value) / Value(pReload.value);
				if (auto pFE = "firing heat" in weapon)
					item.attributes[Attribute.firingHeat  ] = Value(pFE.value) / Value(pReload.value);
			}
		}
		result.items ~= item;
	}
	return result;
}

unittest
{
	assert(getShipData(true).items.find!(i => i.name == "Arach Hulk").front.attributes[Attribute.turretMounts] == 4);
}
