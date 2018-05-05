import std.algorithm.comparison;
import std.algorithm.iteration;
import std.algorithm.sorting;
import std.array;
import std.math;
import std.stdio;

enum playerInitCrew = 465;
enum victimInitCrew = 794;
//enum playerInitCrew = 5;
//enum victimInitCrew = 5;

// C++ shims

uint size(T)(in T[] arr) { return cast(uint)arr.length; }
bool empty(T)(in T[] arr) { return arr.length == 0; }
void resize(T)(ref T[] arr, size_t len) { arr.length = len; }
void resize(T)(ref T[] arr, size_t len, T value)
{
	auto oldLen = arr.length;
	arr.length = len;
	if (oldLen < len)
		arr[oldLen..$] = value;
}
alias unsigned = uint;
void push_back(T)(ref T[] arr, T val) { arr ~= val; }
ref T front(T)(T[] arr) { return arr[0]; }
ref T back(T)(T[] arr) { return arr[$-1]; }

// Some partial data structures

struct Government { int CrewAttack() { return 1; } int CrewDefense() { return 2; } }

struct Outfit
{
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
	this(in ref Ship attacker, in ref Ship defender)
	{
		powerA = Power(attacker, false);
		powerD = Power(defender, true);
		Calculate();
	}

	// Get the odds of the attacker winning if the two ships have the given
	// number of crew members remaining.
	double Odds(int attackingCrew, int defendingCrew) const
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
	double AttackerPower(int attackingCrew) const
	{
		if(uint(attackingCrew - 1) >= powerA.size())
			return 0.;

		return powerA[attackingCrew - 1];
	}



	// Get the total power (inherent crew power plus bonuses from hand to hand
	// weapons) for the defender when they have the given number of crew remaining.
	double DefenderPower(int defendingCrew) const
	{
		if(uint(defendingCrew - 1) >= powerD.size())
			return 0.;

		return powerD[defendingCrew - 1];
	}


private:
	// Generate the lookup tables.
	void Calculate()
	{
		if(powerD.empty() || powerA.empty())
			return;

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
	int Index(int attackingCrew, int defendingCrew) const
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
	double[] Power(in ref Ship ship, bool isDefender)
	{
		double[] power;
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
				power ~= [value].replicate(outfit.count);
		}
		// Use the best weapons first.
		power.sort!"a > b"();

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
	double[] powerA;
	double[] powerD;
	
	// Capture odds lookup table.
	double[] capture;
	// Expected casualties lookup table.
	double[] casualtiesA;
	double[] casualtiesD;
}

immutable CaptureOdds attackOdds, defenseOdds;
shared static this()
{
	auto playerShip = Ship(playerInitCrew, [
		Outfit(2.8, 0.8, playerInitCrew), // nerve gas
		// Outfit(1.6, 2.4, 1), // korath repeater rifle
		// Outfit(0.0, 60.0, 0), // intrusion countermeasures
	]);
	auto victimShip = Ship(victimInitCrew, [
		Outfit(0.0, 60.0, 6), // intrusion countermeasures
	]);
	attackOdds = cast(immutable)CaptureOdds(playerShip, victimShip);
	defenseOdds = cast(immutable)CaptureOdds(victimShip, playerShip);
}

real getWinChance(bool attacking, int playerCrew, int victimCrew)
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

void combineOdds(ref real val, real newVal)
{
	//if (val < newVal) val = newVal;
	// val += newVal;
	//val = 1 - ((1 - val) * newVal);
	// val *= newVal;
	val = min(val + newVal, 1);
}

debug = verbose;

void main()
{
	// How likely we are to get here
	real[victimInitCrew+1][playerInitCrew+1] odds = 0;
	odds[playerInitCrew][victimInitCrew] = 1;

	foreach (step; 0 .. playerInitCrew + victimInitCrew)
	{
		foreach (ofs; 0..step+1)
		{
			auto playerCrew = playerInitCrew - ofs;
			auto victimCrew = victimInitCrew - step + ofs;
			if (playerCrew <= 0 || victimCrew <= 0)
				continue;
			debug(verbose) writefln("== (%d,%d) ==", playerInitCrew-playerCrew, victimInitCrew-victimCrew);

			auto currentOdds = odds[playerCrew][victimCrew];
			if (currentOdds == 0)
				continue;
			assert(currentOdds <= 1);

			real minOdds = 1;
			real maxOdds = 0;

			foreach (attacking; [false, true])
			{
				auto winOdds = getWinChance(attacking, playerCrew, victimCrew);
				if (winOdds.isNaN)
					continue;
				assert(winOdds >= 0);
				assert(winOdds <= 1);
				minOdds = min(minOdds, winOdds);
				maxOdds = max(maxOdds, winOdds);
			}

			auto bestWinOdds = maxOdds;
			auto bestLoseOdds = 1 - minOdds;

			auto oldValue = odds[playerCrew][victimCrew-1];
			combineOdds(odds[playerCrew][victimCrew-1], currentOdds * bestWinOdds);
			debug(verbose) writefln("(%d,%d) += %s * %s (%s): %s -> %s", playerInitCrew-playerCrew, victimInitCrew-(victimCrew-1), currentOdds, bestWinOdds, currentOdds * bestWinOdds, oldValue, odds[playerCrew][victimCrew-1]);

			oldValue = odds[playerCrew-1][victimCrew];
			combineOdds(odds[playerCrew-1][victimCrew], currentOdds * bestLoseOdds);
			debug(verbose) writefln("(%d,%d) += %s * %s (%s): %s -> %s", playerInitCrew-(playerCrew-1), victimInitCrew-victimCrew, currentOdds, bestLoseOdds, currentOdds * bestLoseOdds, oldValue, odds[playerCrew-1][victimCrew]);
		}
	}

	debug(verbose)
	foreach (i, row; odds)
		writefln("%(%10g\t%)", row[]);

	auto winOdds = odds[].map!(row => row[0]).sum();
	writefln("Win odds: %f%% (1 in %d)", 100 * winOdds, cast(int)(1 / winOdds));
}
