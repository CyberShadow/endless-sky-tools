import std.algorithm.iteration;
import std.algorithm.searching;
import std.conv;
import std.exception;
import std.parallelism;
import std.random;
import std.range;
import std.stdio;

import savewriter;
import shipcfg;
import shipdata;

void main()
{
	auto numOutfits = shipData.items.length - shipData.numShips;
	auto maxIterations = numOutfits * numOutfits;

	auto outfitsExpansions = iota(shipData.numShips, shipData.items.length).filter!(d => shipData.items[d].attributes[Attribute.outfitSpace] > 0).map!(.to!ItemIndex).array;

	Score bestScore;
	uint outerIterations = 0;
	auto maxOuterIterations = maxIterations * 5;

	foreach (thread; totalCPUs.iota.parallel(1))
	{
		Xorshift rng;
		rng.seed(unpredictableSeed);

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

				// Try to fix this configuration (optimization)
				while (newConfig.numItems < maxOutfits && newConfig.stats.attributes[Attribute.outfitSpace] < 0 && outfitsExpansions.length)
					newConfig.add(outfitsExpansions[$==1 ? 0 : uniform(0, $)]);

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

			synchronized
			{
				if (bestScore < score)
				{
					bestScore = score;
					writeln("\n\n############################################################################################################################################\n");
					printConfig(config);
					config.save("genship.json");
					createSave(`/home/vladimir/Sync-PC/saves/endless-sky/saves/Test Drive.txt`, [config]);
					outerIterations = 0;
				}
				else
					if (outerIterations++ >= maxOuterIterations)
						break;
			}
			//else { write("."); stdout.flush(); }
		}
	}
}
