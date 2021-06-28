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
import std.utf;

import shipdata;

enum maxOutfits = 128;

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

	/// Assuming we want to turn at least this many degrees per second, how much time do we need to spend turning?
	Value turnTimeRatio(Value degreesPerSecond) const @nogc
	{
		auto turnSpeed = this.turnSpeed;
		if (turnSpeed > degreesPerSecond)
			return degreesPerSecond / turnSpeed;
		else
			return Value(1);
	}

	Value idleEnergy() const @nogc { return stats.attributes[Attribute.energyConsumption] + stats.attributes[Attribute.shieldEnergy]; }
	Value movementEnergy() const @nogc { return idleEnergy + stats.attributes[Attribute.thrustingEnergy] + stats.attributes[Attribute.turningEnergy] * turnTimeRatio(Value(60)); }
	Value battleEnergy() const @nogc { return idleEnergy + stats.attributes[Attribute.firingEnergy]; }
	Value pursueEnergy() const @nogc { return battleEnergy + stats.attributes[Attribute.thrustingEnergy]; }
	Value fullEnergy() const @nogc { return movementEnergy + stats.attributes[Attribute.firingEnergy]; }

	// # of frames we can perform this activity without running out of juice
	Value energyDuration(Value consumption) const @nogc
	{
		auto drain = consumption - stats.attributes[Attribute.energyGeneration];
		if (drain <= 0)
			return Value.max;
		return stats.attributes[Attribute.energyCapacity] / drain;
	}

	// How fast do we drain energy (at full utilization) vs. recharge energy (at idle)?
	Value energyChargeRatio() const @nogc
	{
		auto idleEnergy = this.idleEnergy;
		auto drain = fullEnergy - stats.attributes[Attribute.energyGeneration];
		if (drain <= 0)
			return Value.max;
		auto charge = stats.attributes[Attribute.energyGeneration] - idleEnergy;
		if (charge <= 0)
			return Value(0);
		return charge / drain;
	}

	Value coolingEfficiency() const @nogc
	{
		enum maxIneff = 16;
		static immutable Value[maxIneff] table = (){
			Value[maxIneff] result;
			foreach (ineff; 0..maxIneff)
			{
				double x = ineff;
				result[ineff] = 2. + 2. / (1. + exp(x / -2.)) - 4. / (1. + exp(x / -4.));
			}
			return result;
		}();

		auto v = stats.attributes[Attribute.coolingInefficiency];
		assert(v.isInteger);
		auto ineff = v.to!size_t;
		if (ineff >= maxIneff) return Value(0);
		return table[ineff];
	}

	/// Given this constant heat generation, what heat energy
	/// (temperature*mass) will the ship settle on after an infinite
	/// amount of time?
	Value targetHeat(Value heatGeneration) const @nogc
	{
		auto heatDissipation = .001 * stats.attributes[Attribute.heatDissipation].to!double;

		// This ship's cooling ability:
		/*double*/auto coolingEfficiency = coolingEfficiency();
		auto cooling = coolingEfficiency * stats.attributes[Attribute.cooling];
		//double activeCooling = coolingEfficiency * attributes.Get("active cooling");

		// Idle heat is the heat level where:
		// heat = heat * diss + heatGen - cool - activeCool * heat / (100 * mass)
		// heat = heat * (diss - activeCool / (100 * mass)) + (heatGen - cool)
		// heat * (1 - diss + activeCool / (100 * mass)) = (heatGen - cool)
		double production = max(0, (heatGeneration - cooling).to!double);
		double dissipation = heatDissipation /*+ activeCooling / maxHeat*/;
		return Value(production / dissipation);
	}

	Value idleHeatGeneration() const @nogc
	{
		return stats.attributes[Attribute.heatGeneration]
			+ stats.attributes[Attribute.shieldHeat]
		//	+ stats.attributes[Attribute.hullHeat]
		;
	}

	Value idleHeat() const @nogc
	{
		return targetHeat(idleHeatGeneration);
	}

	/// Ship::MaximumHeat
	Value maxHeat() const @nogc
	{
		enum MAXIMUM_TEMPERATURE = 100;
		return stats.attributes[Attribute.mass] * 100;
	}

	/// A too large mismatch in the velocity of guns can cause trouble
	/// tracking (allowing all guns to stay focus on the target).
	Value gunVelocityMismatch() const @nogc
	{
		Value minVelocity = Value.max, maxVelocity = 0;
		foreach (itemIndex; items[1..numItems])
		{
			auto item = &shipData.items[itemIndex];
			if (item.attributes[Attribute.gunPorts] < 0)
				if (auto velocity = item.weaponVelocity)
				{
					minVelocity = min(minVelocity, velocity);
					maxVelocity = max(maxVelocity, velocity);
				}
		}

		Value velocityMismatch;
		if (maxVelocity && minVelocity != maxVelocity)
		{
			auto minTime = 1000 / maxVelocity;
			auto maxTime = 1000 / minVelocity;
			return 1 - (minTime / maxTime);
		}
		else
			return Value(0);
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
		return cast(int)((log(E + val) - 1) * multiplier);
	}
	static int scale(Value val, int multiplier, double curve = defaultCurve) @nogc { return scale(val.to!double, multiplier, curve); }

	unittest
	{
		assert(scale(0, 1_000_000) == 0);
		assert(scale(1, 1_000_000) > 0);
		assert(scale(1, 1_000_000) < 1);
	}

	void calcScore(T)(ref T cb) const
	{
		void val(string description, Value value, scope bool delegate(Value) @nogc isOK, scope Score delegate(Value) @nogc getScore)
		{
			auto score = getScore ? getScore(value) : 0;
			if (isOK)
			{
				auto ok = isOK(value);
				cb(description, ()=>"[%s] %s".format(ok ? "ok" : "FAIL", value), score + (ok ? 0 : -1_000_000_000));
			}
			else
				cb(description, ()=>value.toString(), score);
		}

		val("hyperdrive"              , stats.attributes[Attribute.hyperdrive    ], v => v > 0                        , null                                    );
	//	val("ramscoop"                , stats.attributes[Attribute.ramscoop      ], v => v > 0                        , null                                    );

		val("movement energy duration", energyDuration(movementEnergy)            , v => v > 60 * 30                  , null                                    );
		val("battle energy duration"  , energyDuration(battleEnergy  )            , v => v > 60 * 10                  , null                                    );
		val("pursue energy duration"  , energyDuration(pursueEnergy  )            , v => v > 60 *  5                  , null                                    );
		val("energy capacity"         , stats.attributes[Attribute.energyCapacity], null                              , v => scale(v, 200_000)                  );
		val("energy charge ratio"     , energyChargeRatio                         , v => v == Value.max || v > 1      , null                                    );

		val("maximum heat"            , maxHeat                                   , null                              , null                                    );
		val("idle heat"               , idleHeat                                  , null                              , null                                    );

		auto movementHeat =
			targetHeat(idleHeatGeneration
					   + stats.attributes[Attribute.thrustingHeat]
					   + stats.attributes[Attribute.turningHeat  ]
					   );
		val("movement heat"           , movementHeat                              , v => v < maxHeat                  , null                                    );

		auto battleHeat =
			targetHeat(idleHeatGeneration
					   + stats.attributes[Attribute.firingHeat]
					   );
		val("battle heat"             , battleHeat                                , v => v < maxHeat                  , null                                    );

		val("acceleration"            , acceleration                              , v => v >= 400                     , v => scale(v, 2_500_000)                );
	//	val("max speed"               , maxSpeed                                  , null                              , v => scale(v, 2_500_000)                );

		val("turning"                 , turnSpeed                                 , v => v >= 160                     , v => scale(v, 2_000_000)                );

		auto shieldDamage = stats.attributes[Attribute.shieldDamage];
		val("shield damage"           , shieldDamage                              , null                              , v => scale(v, 2_000_000)                );

		val("velocity mismatch"       , gunVelocityMismatch                       , null                              , v => -scale(v * shieldDamage, 2_000_000));

		auto shieldGeneration = stats.attributes[Attribute.shieldGeneration];
		val("shield generation"       , shieldGeneration                          , v => v > 0                        , v => scale(v, 2_500_000)                );

	//	val("anti missile"            , stats.attributes[Attribute.antiMissile   ], v => v > 0                        , null                                    );

		val("extra outfits space"     , stats.attributes[Attribute.outfitSpace   ], v => v >= 0                       , null                                    );

		val("cost"                    , stats.attributes[Attribute.cost          ], null                              , v => -v.to!int / 2000                   );

		val("part count"              , Value(numItems)                           , null                              , v => -v.to!int                          );
	}

	void sort()
	{
		items[1..numItems].multiSort!(
			(a, b) => shipData.items[a].category < shipData.items[b].category,
			(a, b) => a < b,
		);
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


void printConfig(in ref Config config)
{
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
	struct Printer { void opCall(lazy string name, scope string delegate() value, Score scoreDelta) { table ~= [name, value(), scoreDelta ? scoreDelta.text : "-"]; } }
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
		.replace(" consumption", " cons.")
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

	auto columnWidths = table.filter!identity.front.length.iota.map!(column => table.filter!identity.map!(row => row[column].byDchar.walkLength).fold!max).array;
	foreach (row; table)
	{
		write("|");
		foreach (column, columnWidth; columnWidths)
			if (row)
				if (column > 0)
					writef(" %*s |", columnWidth, row[column].to!dstring);
				else
					writef(" %-*s |", columnWidth, row[column].to!dstring);
			else
				writef("%s%s", '-'.repeat(columnWidth+2), column+1 == columnWidths.length ? "|" : "+");
		writeln();
	}
}
