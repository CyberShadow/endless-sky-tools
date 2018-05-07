import std.algorithm.comparison;
import std.math;
import std.stdio;

import common;

void combineOdds(ref real val, real newVal)
{
	//if (val < newVal) val = newVal;
	// val += newVal;
	val = 1 - ((1 - val) * (1 - newVal));
	// val *= newVal;
	// val = min(val + newVal, 1);
}

// debug = verbose;

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

	//auto winOdds = odds[].map!(row => row[0]).sum();
	real winOdds = 0;
	foreach (row; odds)
		combineOdds(winOdds, row[0]);
	writefln("Win odds: %f%% (1 in %d)", 100 * winOdds, cast(int)(1 / winOdds));
}
