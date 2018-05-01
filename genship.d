import std.random;
import std.stdio;

import shipcfg;

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
			config.save("genship.json");
		}
		//else { write("."); stdout.flush(); }
	}
}
