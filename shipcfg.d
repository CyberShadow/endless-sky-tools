import ae.utils.array;
import ae.utils.json;
import ae.utils.math;
import ae.utils.meta;
import ae.utils.text;

import std.algorithm.comparison;
import std.algorithm.iteration;
import std.algorithm.searching;
import std.algorithm.sorting;
import std.conv;
import std.file;
import std.math;
import std.range;
import std.stdio;
import std.string;
import std.traits;

import shipdata;

enum maxOutfits = 64;

immutable ShipData shipData;
shared static this() { shipData = cast(immutable)getShipData(); }

alias ItemIndex = uint;

// enum ComputedAttribute : Attribute
// {
// 	_first = EnumLength!Attribute,
// 	maxSpeed = _first,
// }

// struct Parameters
// {
// }

alias Score = long;

struct Config
{
	ItemIndex[maxOutfits] items;
	size_t numItems;
	Item stats;

	void add(ItemIndex itemIndex)
	{
		assert(numItems < maxOutfits);
		immutable Item* item = &shipData.items[itemIndex];
		foreach (a, value; item.attributes)
			stats.attributes[a] += value;
		items[numItems++] = itemIndex;
	}

	void remove(size_t configIndex)
	{
		assert(configIndex > 0 && configIndex < numItems);
		auto itemIndex = items[configIndex];
		immutable Item* item = &shipData.items[itemIndex];
		foreach (a, value; item.attributes)
			stats.attributes[a] -= value;
		items[configIndex] = items[--numItems];
	}

	debug(config)
	invariant
	{
		Item checkStats;
		foreach (configIndex; 0..numItems)
		{
			auto itemIndex = items[configIndex];
			immutable Item* item = &shipData.items[itemIndex];
			foreach (a, value; item.attributes)
				checkStats.attributes[a] += value;
		}
		assert(checkStats == stats);
	}

	/// Check whether any parameter is over capacity.
	/// This shouldn't return false if some component (power, steering) hasn't been added yet.
	bool isOK() const
	{
		if (stats.attributes[Attribute.cargoSpace    ] < 0) return false;
		if (stats.attributes[Attribute.outfitSpace   ] < 0) return false;
		if (stats.attributes[Attribute.weaponCapacity] < 0) return false;
		if (stats.attributes[Attribute.engineCapacity] < 0) return false;
		if (stats.attributes[Attribute.gunPorts      ] < 0) return false;
		if (stats.attributes[Attribute.turretMounts  ] < 0) return false;
		return true;
	}

	bool canAdd(ItemIndex index) const
	{
		Config newConfig = this;
		newConfig.add(index);
		return newConfig.isOK;
	}

	Value maxSpeed() const @nogc
	{
		return 60 * stats.attributes[Attribute.thrust] / stats.attributes[Attribute.drag];
	}

	Value acceleration() const @nogc
	{
		return 3600 * stats.attributes[Attribute.thrust] / stats.attributes[Attribute.mass];
	}

	Value turnSpeed() const @nogc
	{
		return 60 * stats.attributes[Attribute.turn] / stats.attributes[Attribute.mass];
	}

	Value shieldEnergyPerFrame() const @nogc
	{
		auto shieldEnergy = stats.attributes[Attribute.shieldEnergy]; // per unit of shields!
		auto shieldGeneration = stats.attributes[Attribute.shieldGeneration]; // per frame
		return shieldEnergy * shieldGeneration;
	}

	Value movementEnergy() const @nogc { return stats.attributes[Attribute.thrustingEnergy] + stats.attributes[Attribute.turningEnergy]; }
	Value battleEnergy() const @nogc { return stats.attributes[Attribute.firingEnergy] + shieldEnergyPerFrame; }

	// int coolingEfficiency() const @nogc
	// {
	// 	double x = stats.attributes[Attribute.coolingInefficiency];
	// 	return 2. + 2. / (1. + exp(x / -2.)) - 4. / (1. + exp(x / -4.));
	// }

	int idleHeat(Value extraHeat = 0) const @nogc
	{
		auto heatGeneration = stats.attributes[Attribute.heatGeneration] + extraHeat;
		auto heatDissipation = .001 * stats.attributes[Attribute.heatDissipation].to!double;

		// This ship's cooling ability:
		/*double*/auto coolingEfficiency = /*coolingEfficiency()*/1;
		auto cooling = stats.attributes[Attribute.cooling];
		//double activeCooling = coolingEfficiency * attributes.Get("active cooling");

		// Idle heat is the heat level where:
		// heat = heat * diss + heatGen - cool - activeCool * heat / (100 * mass)
		// heat = heat * (diss - activeCool / (100 * mass)) + (heatGen - cool)
		// heat * (1 - diss + activeCool / (100 * mass)) = (heatGen - cool)
		double production = max(0, (heatGeneration - cooling).to!double);
		double dissipation = heatDissipation /*+ activeCooling / maximumHeat*/;
		return cast(int)(production / dissipation);
	}

	Value maximumHeat() const @nogc
	{
		return stats.attributes[Attribute.mass] * 100;
	}

	Score score() const @nogc
	{
		static struct Collector
		{
			Score score;
			void opCall(lazy string name, scope string delegate() value, Score scoreDelta) @nogc
			{
				score += scoreDelta;
			}
		}
		Collector collector;
		calcScore(collector);
		return collector.score;
	}

	enum defaultCurve = 0.8;
	static int scale(double val, int multiplier, double curve = defaultCurve) @nogc
	{
		return cast(int)(log(E + val) * multiplier);
	}
	static int scale(Value val, int multiplier, double curve = defaultCurve) @nogc { return scale(val.to!double, multiplier, curve); }

	void calcScore(T)(ref T cb) const
	{
		void sanityCheck(bool condition, string description)
		{
			if (condition)
				cb(description, ()=>"ok", 0);
			else
				cb(description, ()=>"FAIL", -1_000_000_000);
		}

		sanityCheck(stats.attributes[Attribute.hyperdrive] > 0, "hyperdrive present?");
		sanityCheck(movementEnergy < stats.attributes[Attribute.energyGeneration], "movement energy ok?"); // TODO capacity
		cb("shield energy / frame", ()=>shieldEnergyPerFrame.text, 0);
		cb("battle energy", ()=>battleEnergy.text, 0);
		sanityCheck(battleEnergy < stats.attributes[Attribute.energyGeneration], "battle energy ok?"); // TODO capacity

		cb("maximum heat", ()=>maximumHeat.text, 0);
		cb("idle heat", ()=>idleHeat.text, 0);

		sanityCheck(stats.attributes[Attribute.outfitSpace] >= 1, "extra outfits space");

		auto movementHeat = idleHeat(stats.attributes[Attribute.thrustingHeat] + stats.attributes[Attribute.turningHeat]);
		cb("movement heat", ()=>movementHeat.text, 0);
		sanityCheck(movementHeat < maximumHeat, "movement heat ok?");

		auto battleHeat = idleHeat(stats.attributes[Attribute.firingHeat] + stats.attributes[Attribute.shieldHeat]);
		cb("battle heat", ()=>battleHeat.text, 0);
		sanityCheck(battleHeat < maximumHeat, "battle heat ok?");

		cb("acceleration", ()=>acceleration.text, scale(acceleration, 2_500_000));

		cb("turning", ()=>turnSpeed.text, scale(turnSpeed, 2_000_000));

		auto shieldDamage = stats.attributes[Attribute.shieldDamage];
		cb("shield damage", ()=>shieldDamage.text, scale(shieldDamage, 2_000_000));

		auto shieldGeneration = stats.attributes[Attribute.shieldGeneration];
		cb("shield generation", ()=>shieldGeneration.text, scale(shieldGeneration, 2_500_000));

		auto cost = stats.attributes[Attribute.cost];
		cb("cost", ()=>cost.text, -cost.to!int / 2000);
	}

	void save(string fn)
	{
		auto data = items[0..numItems].map!(item => shipData.items[item].name).array;
		data.toPrettyJson.toFile(fn);
	}

	static Config load(string fn)
	{
		Config config;
		auto data = fn.readText.jsonParse!(string[]);
		foreach (name; data)
			config.add(shipData.items.countUntil!(i => i.name == name).to!ItemIndex);
		return config;
	}
}

bool showAttribute(Attribute attr)
{
	switch (attr)
	{
		case Attribute.drag:
		case Attribute.hyperdrive:
			return false;
		default:
			return true;
	}
}


void printConfig(in ref Config inConfig)
{
	Config config = inConfig;
	config.items[1..config.numItems].sort();

	writefln("%d/%d outfits:", config.numItems, maxOutfits);
	string[][] table;
	table ~= null;
	table ~= ["name"] ~ [EnumMembers!Attribute].filter!showAttribute.map!(a => attributeNames[a]).map!abbrevAttr.map!minWrap.array;
	table ~= null;
	foreach (item; config.items[0..config.numItems])
		table ~= [shipData.items[item].name] ~ [EnumMembers!Attribute].filter!showAttribute.map!(a => shipData.items[item].attributes[a].I!(n => n ? n.to!string : "")).array;
	table ~= null;
	table ~= ["Total"] ~ [EnumMembers!Attribute].filter!showAttribute.map!(a => config.stats.attributes[a].to!string).array;
	table ~= null;
	printTable(table);

	writeln();
	table = [[], ["stat", "value", "score"], []];
	struct Printer { void opCall(lazy string name, scope string delegate() value, Score scoreDelta) { table ~= [name, value(), scoreDelta.text]; } }
	Printer printer; config.calcScore(printer);
	table ~= null;
	table ~= ["total", null, numberToString(config.score)];
	table ~= null;
	printTable(table);
}

string abbrevAttr(string s)
{
	return s
		.replace("thrusting ", "thrust ")
		.replace("turning ", "turn ")
		.replace(" capacity", " cap.")
		.replace(" generation", " gen.")
		.replace(" inefficiency", " ineff.")
		.replace(" dissipation", " diss.")
	;
}

string minWrap(string s)
{
	return s.wrap(s.split.map!(s => s.length).fold!max);
}

void printTable(string[][] table)
{
	// Convert newlines in table cells into multiple rows
	table = table
		.map!(row => row is null ? [(string[]).init] : row
			.map!(cell => cell.splitLines.length)
			.fold!max(size_t.init)
			.I!(maxLines =>
				maxLines
				.iota
				.map!(line =>
					row
					.map!(cell => cell.splitLines.get(line, null))
					.array
				)
				.array
			)
		)
		.join.
		array;

	auto columnWidths = table.filter!identity.front.length.iota.map!(column => table.filter!identity.map!(row => row[column].length).fold!max).array;
	foreach (row; table)
	{
		write("|");
		foreach (column, columnWidth; columnWidths)
			if (row)
				if (column > 0)
					writef(" %*s |", columnWidth, row[column]);
				else
					writef(" %-*s |", columnWidth, row[column]);
			else
				writef("%s%s", '-'.repeat(columnWidth+2), column+1 == columnWidths.length ? "|" : "+");
		writeln();
	}
}
