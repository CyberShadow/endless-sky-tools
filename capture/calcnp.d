import std.experimental.allocator;
import std.math;

import alloc;
import common;

void combineOdds(ref real val, real newVal) @nogc
{
	val += newVal;
}

// debug = verbose;

struct Result
{
	real[][] odds;
	real winOdds;
}

Result calculate(in ref Problem problem) @nogc
{
	Result result;

	// How likely we are to get here
	result.odds = allocator.makeArray!(real[])(problem.playerInitCrew+1);
	foreach (ref row; result.odds)
		row = allocator.makeArray!real(problem.victimInitCrew+1, 0);
	result.odds[problem.playerInitCrew][problem.victimInitCrew] = 1;

	foreach (step; 0 .. problem.playerInitCrew + problem.victimInitCrew + 2)
	{
		foreach (ofs; 0..step+1)
		{
			auto playerCrew = problem.playerInitCrew - ofs;
			auto victimCrew = problem.victimInitCrew - step + ofs;
			if (playerCrew < 0 || victimCrew < 0)
				continue;
			//debug(verbose) writefln("== (%d,%d) / (%d,%d) ==", playerInitCrew-playerCrew, victimInitCrew-victimCrew, playerCrew, victimCrew);

			auto currentOdds = result.odds[playerCrew][victimCrew];
			if (currentOdds == 0)
				continue;
			assert(currentOdds <= 1);

			bool attacking;
			if (playerCrew != 0 && victimCrew != 0)
				attacking = problem.shouldAttack(playerCrew, victimCrew);

			auto winOdds = problem.getWinChance(attacking, playerCrew, victimCrew);
			if (winOdds.isNaN)
				continue;
			assert(winOdds >= 0);
			assert(winOdds <= 1);

			if (victimCrew > 0)
			{
				auto oldValue = result.odds[playerCrew][victimCrew-1];
				combineOdds(result.odds[playerCrew][victimCrew-1], currentOdds * winOdds);
				//debug(verbose) writefln("(%d,%d) += %s * %s (%s): %s -> %s", playerInitCrew-playerCrew, victimInitCrew-(victimCrew-1), currentOdds, winOdds, currentOdds * winOdds, oldValue, odds[playerCrew][victimCrew-1]);
			}

			if (playerCrew > 0)
			{
				auto loseOdds = 1 - winOdds;
				auto oldValue = result.odds[playerCrew-1][victimCrew];
				combineOdds(result.odds[playerCrew-1][victimCrew], currentOdds * loseOdds);
				//debug(verbose) writefln("(%d,%d) += %s * %s (%s): %s -> %s", playerInitCrew-(playerCrew-1), victimInitCrew-victimCrew, currentOdds, loseOdds, currentOdds * loseOdds, oldValue, odds[playerCrew-1][victimCrew]);
			}
		}
	}

	//auto winOdds = odds[].map!(row => row[0]).sum();
	result.winOdds = 0;
	foreach (row; result.odds)
		combineOdds(result.winOdds, row[0]);

	return result;
}

version (dscripten) {} else
void main()
{
	import std.stdio;

	auto problem = getProblem();
	auto result = calculate(problem);

	debug(verbose)
	foreach (i, row; result.odds)
		writefln("%(%10g\t%)", row[]);

	writefln("Win odds: %f%% (1 in %d)", 100 * result.winOdds, cast(int)(1 / result.winOdds));
}
