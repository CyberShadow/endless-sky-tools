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
		foreach (Attribute attr; Attribute.init .. enumLength!Attribute)
		{
			auto name = attributeNames[attr];
			auto pNode = name in node;
			if (pNode)
			{
				auto value = (*pNode).value;
				scope(failure) writefln("Error parsing attribute %(%s%) with value %(%s%)", [name], [value]);
				attributes[attr] = value.strip;
			}
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
	foreach (name, node; gameData["ship"])
	{
		scope(failure) stderr.writeln("Error with ship: " ~ name);
		if (!all && name !in knownItems) continue;
		Item item;
		item.name = name;
		if (auto pNode = "attributes" in node)
			item.fromAttributes(*pNode);
		else
		{
			stderr.writeln("Skipping ship without attributes (variant?): ", name);
			continue;
		}
		if (auto pNode = "gun" in node)
			item.attributes[Attribute.gunPorts] = (){ int count; pNode.iterLeaves((_){count++;}); return count; }();
		if (auto pNode = "turret" in node)
			item.attributes[Attribute.turretMounts] = (){ int count; pNode.iterLeaves((_){count++;}); return count; }();
		result.items ~= item;
	}
	result.numShips = result.items.length.to!uint;

	foreach (name, node; gameData["outfit"])
	{
		scope(failure) writefln("Error parsing outfit %(%s%):", [name]);
		if (!all && name !in knownItems) continue;
		Item item;
		item.name = name;
		item.fromAttributes(node);
		if (auto pStr = "category" in node)
		{
			if (pStr.value.isOneOf("Hand to Hand", "Ammunition", "Special"))
				continue;
			item.category = pStr.value;
		}
		if (auto pStr = "installable" in node)
			if (Value(pStr.value) < 0)
				continue;
		if (auto pWeapon = "weapon" in node)
		{
			if ("ammo" in *pWeapon)
				continue; // TODO: tons / cost of ammo per unit of time / damage?
			if (auto pVelocity = "velocity" in *pWeapon)
				item.weaponVelocity = Value(pVelocity.value);
			foreach (attribute; [Attribute.antiMissile])
				if (auto pValue = attributeNames[attribute] in *pWeapon)
					item.attributes[attribute] += Value((*pValue).value.strip);

			// Estimate effective DPS accounting for accuracy and projectile travel time
			Value accMultiplier = 1;
			if (auto pStr = "inaccuracy" in *pWeapon)
				accMultiplier = (100 - min(Value(100), Value(pStr.value) * 4)) / 100;
			auto travelTime = 1 / max(Value(1), item.weaponVelocity * 3 / 2);
			auto speedMultiplier = 1 - travelTime;

			auto projMultiplier = accMultiplier * speedMultiplier;
			debug(weapon_multiplier) writefln("%s\t%s\t%s\t%s", accMultiplier, speedMultiplier, projMultiplier, name);

			if (auto pReload = "reload" in *pWeapon)
			{
				if (auto pSD = "shield damage" in *pWeapon)
					item.attributes[Attribute.shieldDamage] = Value(pSD.value) / Value(pReload.value) * projMultiplier;
				if (auto pFE = "firing energy" in *pWeapon)
					item.attributes[Attribute.firingEnergy] = Value(pFE.value) / Value(pReload.value);
				if (auto pFE = "firing heat" in *pWeapon)
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
