import std.algorithm.comparison;
import std.math;
import std.random;
import std.stdio;

import common;

//debug = verbose;

void main()
{
	auto problem = getProblem();

	int playerWins, totalWins;
	int seed = 0;
	while (true)
	{
		Xorshift rng;
		rng.seed(++seed);
		auto playerCrew = problem.playerInitCrew;
		auto victimCrew = problem.victimInitCrew;

		while (playerCrew && victimCrew)
		{
			auto playerAttackPower = problem.attackOdds.AttackerPower(playerCrew);
			auto playerDefensePower = problem.defenseOdds.DefenderPower(playerCrew);
			auto victimAttackPower = problem.defenseOdds.AttackerPower(victimCrew);
			auto victimDefensePower = problem.attackOdds.DefenderPower(victimCrew);

			bool attacking = problem.shouldAttack(playerCrew, victimCrew);

			auto winOdds = problem.getWinChance(attacking, playerCrew, victimCrew);
			bool won = uniform(0.0, 1.0, rng) < winOdds;

			debug(verbose)
				writefln(q"EOF
---------------------------------------
		crew	attack	defense
your ship:	%d	%s	%s
enemy ship:	%d	%s	%s

capture odds (attacking):	%s%%
exected casualties:		%s

survival odds (defending):	%s%%
exected casualties:		%s

Win odds: %s%%
You %s, they %s. %s lose 1 crew.
EOF",
					playerCrew, playerAttackPower, playerDefensePower,
					victimCrew, victimAttackPower, victimDefensePower,

					100. * attackOdds.Odds(playerCrew, victimCrew),
					attackOdds.AttackerCasualties(playerCrew, victimCrew),

					100. * (1. - defenseOdds.Odds(victimCrew, playerCrew)),
					defenseOdds.DefenderCasualties(victimCrew, playerCrew),

					100 * winOdds,
					attacking ? "attack" : "defend",
					enemyWillAttack(playerCrew, victimCrew) ? "attack" : "defend",
					won ? "They" : "You",
				);

			if (won)
				victimCrew--;
			else
				playerCrew--;
		}

		if (playerCrew)
		{
			playerWins++;
			writefln("Won with seed %d", seed);
		}
		totalWins++;
		if (totalWins % 1000 == 0)
			writefln("%d / %d (%s%%) (one in %d)", playerWins, totalWins, real(playerWins) / totalWins, playerWins ? totalWins/playerWins : 0);
		debug(verbose) break;
	}
}
