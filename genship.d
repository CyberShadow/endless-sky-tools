import ae.utils.array;
import ae.utils.math;
import ae.utils.meta;
import ae.utils.text;

import std.algorithm.comparison;
import std.algorithm.iteration;
import std.algorithm.sorting;
import std.conv;
import std.random;
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
		stats.attributes[] += item.attributes[];
		items[numItems++] = itemIndex;
	}

	void remove(size_t configIndex)
	{
		assert(configIndex > 0 && configIndex < numItems);
		auto itemIndex = items[configIndex];
		immutable Item* item = &shipData.items[itemIndex];
		stats.attributes[] -= item.attributes[];
		items[configIndex] = items[--numItems];
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

	int maxSpeed() const @nogc
	{
		return 60 * stats.attributes[Attribute.thrust] / stats.attributes[Attribute.drag];
	}

	int acceleration() const @nogc
	{
		return 3600 * stats.attributes[Attribute.thrust] / stats.attributes[Attribute.mass]
			/ attributeMultiplier[Attribute.thrust] / attributeMultiplier[Attribute.mass];
	}

	int turnSpeed() const @nogc
	{
		return 60 * stats.attributes[Attribute.turn] / stats.attributes[Attribute.mass]
			/ attributeMultiplier[Attribute.turn] / attributeMultiplier[Attribute.mass];
	}

	int movementEnergy() const @nogc
	{
		return stats.attributes[Attribute.thrustingEnergy] + stats.attributes[Attribute.turningEnergy];
	}

	// int coolingEfficiency() const @nogc
	// {
	// 	double x = stats.attributes[Attribute.coolingInefficiency];
	// 	return 2. + 2. / (1. + exp(x / -2.)) - 4. / (1. + exp(x / -4.));
	// }

	int idleHeat(double extraHeat = 0) const @nogc
	{
		auto heatGeneration = stats.attrFP!(Attribute.heatGeneration) + extraHeat;
		auto heatDissipation = .001 * stats.attrFP!(Attribute.heatDissipation);

		// This ship's cooling ability:
		/*double*/auto coolingEfficiency = /*coolingEfficiency()*/1;
		auto cooling = stats.attrFP!(Attribute.cooling);
		//double activeCooling = coolingEfficiency * attributes.Get("active cooling");

		// Idle heat is the heat level where:
		// heat = heat * diss + heatGen - cool - activeCool * heat / (100 * mass)
		// heat = heat * (diss - activeCool / (100 * mass)) + (heatGen - cool)
		// heat * (1 - diss + activeCool / (100 * mass)) = (heatGen - cool)
		double production = max(0, heatGeneration - cooling);
		double dissipation = heatDissipation /*+ activeCooling / maximumHeat*/;
		return cast(int)(production / dissipation);
	}

	int maximumHeat() const @nogc
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
		sanityCheck(stats.attributes[Attribute.firingEnergy] < stats.attributes[Attribute.energyGeneration], "firing energy ok?"); // TODO capacity

		cb("maximum heat", ()=>maximumHeat.text, 0);
		cb("idle heat", ()=>idleHeat.text, 0);

		auto movementHeat = idleHeat(stats.attrFP!(Attribute.thrustingHeat) + stats.attrFP!(Attribute.turningHeat));
		cb("movement heat", ()=>movementHeat.text, 0);
		sanityCheck(movementHeat < maximumHeat, "movement heat ok?");

		auto firingHeat = idleHeat(stats.attrFP!(Attribute.firingHeat));
		cb("firing heat", ()=>firingHeat.text, 0);
		sanityCheck(firingHeat < maximumHeat, "firing heat ok?");

		auto accScore = acceleration * 5;
		cb("acceleration", ()=>acceleration.text, ilog2(accScore) * 1_000_000 + accScore);

		auto turnScore = turnSpeed * 10;
		cb("turning", ()=>turnSpeed.text, ilog2(turnScore) * 1_000_000 + turnScore);

		auto shieldDamage = stats.attributes[Attribute.shieldDamage];
		cb("shield damage", ()=>shieldDamage.text, shieldDamage * 2_000);

		auto cost = stats.attributes[Attribute.cost];
		cb("cost", ()=>cost.text, -cost / 10);
	}
}

void main()
{
	Xorshift rng;
	rng.seed(unpredictableSeed);

	auto numOutfits = shipData.items.length - shipData.numShips;
	auto maxIterations = numOutfits * numOutfits;

	Score bestScore;

	while (true)
	{
		Config config;
		config.add(uniform(0, shipData.numShips, rng));
		Score score = config.score;

		uint iterations;
		while (iterations < maxIterations)
		{
			auto newConfig = config;
			foreach (n; 0..uniform(0, 3, rng))
				if (newConfig.numItems > 1)
					newConfig.remove(uniform(1, newConfig.numItems, rng));
			foreach (n; 0..uniform(0, 3, rng))
				if (newConfig.numItems < maxOutfits)
					newConfig.add(uniform(shipData.numShips, cast(ItemIndex)shipData.items.length, rng));
			if (newConfig.isOK)
			{
				auto newScore = newConfig.score;
				if (score < newScore)
				{
					config = newConfig;
					score = newScore;
					iterations = 0;
				}
			}
			iterations++;
		}

		if (bestScore < score)
		{
			bestScore = score;
			writeln("\n\n############################################################################################################################################\n");
			printConfig(config);
		}
		//else { write("."); stdout.flush(); }
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
		table ~= [shipData.items[item].name] ~ [EnumMembers!Attribute].filter!showAttribute.map!(a => shipData.items[item].attributes[a].I!(n => n ? formatAttribute(a, n) : "")).array;
	table ~= null;
	table ~= ["Total"] ~ [EnumMembers!Attribute].filter!showAttribute.map!(a => formatAttribute(a, config.stats.attributes[a])).array;
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

string formatAttribute(Attribute attr, int value)
{
	return isFractional(attr)
		? numberToString(double(value) / fractionalMultiplier)
		: value.to!string;
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
