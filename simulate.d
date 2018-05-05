import std.algorithm.comparison;
import std.math;
import std.random;
import std.stdio;

import common;

//debug = verbose;

void main()
{
	int playerWins, totalWins;
	while (true)
	{
		auto playerCrew = playerInitCrew;
		auto victimCrew = victimInitCrew;

		while (playerCrew && victimCrew)
		{
			auto playerAttackPower = attackOdds.AttackerPower(playerCrew);
			auto playerDefensePower = defenseOdds.DefenderPower(playerCrew);
			auto victimAttackPower = defenseOdds.AttackerPower(victimCrew);
			auto victimDefensePower = attackOdds.DefenderPower(victimCrew);

			bool attacking = shouldAttack(playerCrew, victimCrew);

			auto winOdds = getWinChance(attacking, playerCrew, victimCrew);
			bool won = uniform(0.0, 1.0) < winOdds;

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
You %s. %s lose 1 crew.
EOF",
					playerCrew, playerAttackPower, playerDefensePower,
					victimCrew, victimAttackPower, victimDefensePower,

					100. * attackOdds.Odds(playerCrew, victimCrew),
					attackOdds.AttackerCasualties(playerCrew, victimCrew),

					100. * (1. - defenseOdds.Odds(victimCrew, playerCrew)),
					defenseOdds.DefenderCasualties(victimCrew, playerCrew),

					100 * winOdds,
					attacking ? "attack" : "defend",
					won ? "They" : "You",
				);

			if (won)
				victimCrew--;
			else
				playerCrew--;
		}

		if (playerCrew)
			playerWins++;
		totalWins++;
		if (totalWins % 1000 == 0)
			writefln("%d / %d (%s%%) (one in %d)", playerWins, totalWins, real(playerWins) / totalWins, playerWins ? totalWins/playerWins : 0);
		debug(verbose) break;
	}
}
