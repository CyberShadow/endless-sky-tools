import std.algorithm.comparison;
import std.algorithm.iteration;
import std.algorithm.sorting;
import std.array;
import stdx.allocator : makeArray;

import alloc;

@nogc:

// C++ shims

struct Vector(T)
{
	T[] buf;
	size_t length;

	uint size() const { return cast(uint)length; }

	bool empty() const { return length == 0; }
	void resize(size_t len) { reserve(len); length = len; }
	void resize(size_t len, T value)
	{
		reserve(len);
		auto oldLen = length;
		length = len;
		if (oldLen < len)
			buf[oldLen..$] = value;
	}
	void reserve(size_t len)
	{
		if (len < buf.length)
			return;
		auto newBuf = allocator.makeArray!T(len);
		newBuf[0..length] = buf[0..length];
		buf = newBuf;
	}
	void push_back(T val) { if (length == buf.length) reserve(max(16, length * 2)); buf[length++] = val; }
	ref inout(T) front() inout { return buf[0]; }
	ref inout(T) back() inout { return buf[length-1]; }
	ref inout(T) opIndex(size_t n) inout { return buf[n]; }
	inout(T)[] opSlice() inout { return buf[0..length]; }

	void opIndexOpAssign(string op)(T val, size_t n)
	{
		buf[n] = mixin(`buf[n]` ~ op ~ `val`);
	}
}
alias unsigned = uint;

// Some partial data structures

struct Government { @nogc: int CrewAttack() { return 1; } int CrewDefense() { return 2; } }

struct Outfit
{
@nogc:
	double captureAttack, captureDefense;
	uint count;

	double Get(string name) const
	{
		switch (name)
		{
			case "capture attack":
				return captureAttack;
			case "capture defense":
				return captureDefense;
			default:
				assert(false);
		}
	}
}

struct Ship
{
@nogc:
	this(int crew, Outfit[] outfits) { this.crew = crew; this.outfits = outfits; }
	int Crew() const { return crew; }
	const(Outfit)[] Outfits() const { return outfits; }
	Government GetGovernment() const { return Government.init; }
private:
	int crew;
	Outfit[] outfits;
}

// Main logic - left as close as possible to the original game code

struct CaptureOdds
{
public:
	this(in ref Ship attacker, in ref Ship defender) @nogc
	{
		powerA = Power(attacker, false);
		powerD = Power(defender, true);
		Calculate();
	}

	// Get the odds of the attacker winning if the two ships have the given
	// number of crew members remaining.
	double Odds(int attackingCrew, int defendingCrew) const @nogc
	{
		// If the defender has no crew remaining, odds are 100%.
		if(!defendingCrew)
			return 1.;

		// Make sure the input is within range, with the special constraint that the
		// attacker can never succeed if they don't have two crew left (one to pilot
		// each of the ships).
		int index = Index(attackingCrew, defendingCrew);
		if(attackingCrew < 2 || index < 0)
			return 0.;

		return capture[index];
	}



	// Get the expected number of casualties for the attacker in the remainder of
	// the battle if the two ships have the given number of crew remaining.
	double AttackerCasualties(int attackingCrew, int defendingCrew) const
	{
		// If the attacker has fewer than two crew, they cannot attack. If the
		// defender has no crew, they cannot defend (so casualties will be zero).
		int index = Index(attackingCrew, defendingCrew);
		if(attackingCrew < 2 || !defendingCrew || index < 0)
			return 0.;

		return casualtiesA[index];
	}



	// Get the expected number of casualties for the defender in the remainder of
	// the battle if the two ships have the given number of crew remaining.
	double DefenderCasualties(int attackingCrew, int defendingCrew) const
	{
		// If the attacker has fewer than two crew, they cannot attack. If the
		// defender has no crew, they cannot defend (so casualties will be zero).
		int index = Index(attackingCrew, defendingCrew);
		if(attackingCrew < 2 || !defendingCrew || index < 0)
			return 0.;

		return casualtiesD[index];
	}



	// Get the total power (inherent crew power plus bonuses from hand to hand
	// weapons) for the attacker when they have the given number of crew remaining.
	double AttackerPower(int attackingCrew) const @nogc
	{
		if(uint(attackingCrew - 1) >= powerA.size())
			return 0.;

		return powerA[attackingCrew - 1];
	}



	// Get the total power (inherent crew power plus bonuses from hand to hand
	// weapons) for the defender when they have the given number of crew remaining.
	double DefenderPower(int defendingCrew) const @nogc
	{
		if(uint(defendingCrew - 1) >= powerD.size())
			return 0.;

		return powerD[defendingCrew - 1];
	}


private:
	// Generate the lookup tables.
	void Calculate() @nogc
	{
		if(powerD.empty() || powerA.empty())
			return;

		capture.reserve(powerA.size() * powerD.size());
		casualtiesA.reserve(powerA.size() * powerD.size());
		casualtiesD.reserve(powerA.size() * powerD.size());

		// The first row represents the case where the attacker has only one crew left.
		// In that case, the defending ship can never be successfully captured.
		capture.resize(powerD.size(), 0.);
		casualtiesA.resize(powerD.size(), 0.);
		casualtiesD.resize(powerD.size(), 0.);
		unsigned up = 0;
		for(unsigned a = 2; a <= powerA.size(); ++a)
		{
			double ap = powerA[a - 1];
			// Special case: odds for defender having only one person,
			// because 0 people is outside the end of the table.
			double odds = ap / (ap + powerD[0]);
			capture.push_back(odds + (1. - odds) * capture[up]);
			casualtiesA.push_back((1. - odds) * (casualtiesA[up] + 1.));
			casualtiesD.push_back(odds + (1. - odds) * casualtiesD[up]);
			++up;

			// Loop through each number of crew the defender might have.
			for(unsigned d = 2; d <= powerD.size(); ++d)
			{
				// This is  basic 2D dynamic program, where each value is based on
				// the odds of success and the values for one fewer crew members
				// for the defender or the attacker depending on who wins.
				odds = ap / (ap + powerD[d - 1]);
				capture.push_back(odds * capture.back() + (1. - odds) * capture[up]);
				casualtiesA.push_back(odds * casualtiesA.back() + (1. - odds) * (casualtiesA[up] + 1.));
				casualtiesD.push_back(odds * (casualtiesD.back() + 1.) + (1. - odds) * casualtiesD[up]);
				++up;
			}
		}
	}



	// Map the given crew complements to an index in the lookup tables. There is no
	// row in the table for 0 crew on either ship.
	int Index(int attackingCrew, int defendingCrew) const @nogc
	{
		if(uint(attackingCrew - 1) > powerA.size())
			//return -1;
			assert(false);
		if(uint(defendingCrew - 1) > powerD.size())
			//return -1;
			assert(false);

		return (attackingCrew - 1) * powerD.size() + (defendingCrew - 1);
	}



	// Generate a vector with the total power of the given ship's crew when any
	// number of them are left, either for attacking or for defending.
	Vector!double Power(in ref Ship ship, bool isDefender) @nogc
	{
		Vector!double power;
		if(!ship.Crew())
			return power;

		// Check for any outfits that assist with attacking or defending:
		const string attribute = (isDefender ? "capture defense" : "capture attack");
		const double crewPower = (isDefender ?
			ship.GetGovernment().CrewDefense() : ship.GetGovernment().CrewAttack());

		// Each crew member can wield one weapon. They use the most powerful ones
		// that can be wielded by the remaining crew.
		foreach(outfit; ship.Outfits())
		{
			double value = outfit.Get(attribute);
			if(value > 0. && outfit.count > 0)
				foreach (n; 0..outfit.count)
					power.push_back(value);
		}
		// Use the best weapons first.
		power[].sort!"a > b"();

		// Resize the vector to have exactly one entry per crew member.
		power.resize(ship.Crew(), 0.);

		// Calculate partial sums. That is, power[N - 1] should be your total crew
		// power when you have N crew left.
		power.front() += crewPower;
		for(unsigned i = 1; i < power.size(); ++i)
			power[i] += power[i - 1] + crewPower;

		return power;
	}

private:
	Vector!double powerA;
	Vector!double powerD;
	
	// Capture odds lookup table.
	Vector!double capture;
	// Expected casualties lookup table.
	Vector!double casualtiesA;
	Vector!double casualtiesD;
}

struct Problem
{
	@nogc:
	int playerInitCrew, victimInitCrew;

	CaptureOdds attackOdds, defenseOdds;

	this(int playerCrew, int victimCrew, Ship playerShip, Ship victimShip)
	{
		this.playerInitCrew = playerCrew;
		this.victimInitCrew = victimCrew;

		attackOdds = CaptureOdds(playerShip, victimShip);
		defenseOdds = CaptureOdds(victimShip, playerShip);
	}

	bool enemyWillAttack(int playerCrew, int victimCrew) const
	{
		if (playerCrew == playerInitCrew && victimCrew == victimInitCrew)
			return false;
		return defenseOdds.Odds(victimCrew, playerCrew) > .5;
	}

	real getWinChance(bool attacking, int playerCrew, int victimCrew) const
	{
		if (playerCrew == 0)
			return 0;
		if (victimCrew == 0)
			return 1;
		if (attacking && playerCrew <= 1)
			return real.nan;

		bool isFirstCaptureAction = playerCrew == playerInitCrew && victimCrew == victimInitCrew;

		int yourStartCrew = playerCrew;
		int enemyStartCrew = victimCrew;

		// Figure out what action the other ship will take. As a special case,
		// if you board them but immediately "defend" they will let you return
		// to your ship in peace. That is to allow the player to "cancel" if
		// they did not really mean to try to capture the ship.
		bool youAttack = attacking;
		bool enemyAttacks = defenseOdds.Odds(enemyStartCrew, yourStartCrew) > .5;
		if(isFirstCaptureAction && !youAttack)
			enemyAttacks = false;
		isFirstCaptureAction = false;

		// If neither side attacks, combat ends.
		if(!youAttack && !enemyAttacks)
		{
			//messages.push_back("You retreat to your ships. Combat ends.");
			//isCapturing = false;
			return real.nan;
		}
		else
		{
			int yourCrew = playerCrew;
			int enemyCrew = victimCrew;
			if(!yourCrew || !enemyCrew)
				assert(false);

			// Your chance of winning this round is equal to the ratio of
			// your power to the enemy's power.
			double yourPower = (youAttack ?
				attackOdds.AttackerPower(yourCrew) : defenseOdds.DefenderPower(yourCrew));
			double enemyPower = (enemyAttacks ?
				defenseOdds.AttackerPower(enemyCrew) : attackOdds.DefenderPower(enemyCrew));

			double total = yourPower + enemyPower;
			if(!total)
				assert(false);

			return yourPower / total;
		}

	}

	bool shouldAttack(int playerCrew, int victimCrew) const
	{
		return
			(playerCrew == playerInitCrew && victimCrew == victimInitCrew) ? true :
			attackOdds.AttackerPower(playerCrew) > defenseOdds.DefenderPower(playerCrew) ? true :
			defenseOdds.Odds(victimCrew, playerCrew) > .5 ? false :
			true;
	}
}

Problem getProblem() @nogc
{
	enum playerInitCrew = 465;
	enum victimInitCrew = 794;

	return Problem(
		playerInitCrew,
		victimInitCrew,

		// playerShip
		Ship(playerInitCrew, allocator.makeArray!Outfit(1,
			Outfit(2.8, 0.8, playerInitCrew), // nerve gas
			// Outfit(1.6, 2.4, 1), // korath repeater rifle
			// Outfit(0.0, 60.0, 0), // intrusion countermeasures
		)),

		// victimShip
		Ship(victimInitCrew, allocator.makeArray!Outfit(1,
			//Outfit(0.0, 60.0, 6), // intrusion countermeasures
			Outfit(1.6, 2.4, 150), // korath repeater rifle
		)),
	);
}
