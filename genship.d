import std.algorithm.iteration;
import std.algorithm.searching;
import std.conv;
import std.datetime.stopwatch : StopWatch;
import std.exception;
import std.parallelism;
import std.random;
import std.range;
import std.stdio;

import savewriter;
import shipcfg;
import shipdata;

//debug = metalog;

void main()
{
	immutable numOutfits = cast(ItemIndex)(shipData.items.length - shipData.numShips);
	immutable outfitsExpansions = iota(shipData.numShips, shipData.items.length).filter!(d => shipData.items[d].attributes[Attribute.outfitSpace] > 0).map!(.to!ItemIndex).array;

	Score bestScore = Score.min;
	uint outerIterations = 0;
	immutable maxOuterIterations = numOutfits * numOutfits * 5;

	debug(metalog) auto metaLog = File("metalog.txt", "ab");

	void searchThread()
	{
		Xorshift rng;
		rng.seed(unpredictableSeed);

		void genConfig(ref Config config)
		{
			config.add(uniform(0, shipData.numShips, rng));
		}

		void mutate(ref Config config)
		{
			foreach (n; 0..uniform(0, 3, rng))
				if (config.numItems > 1)
					config.remove(uniform(1, config.numItems, rng));

			foreach (n; 0..uniform(0, 3, rng))
				if (config.numItems < maxOutfits)
					config.add(uniform(shipData.numShips, cast(ItemIndex)shipData.items.length, rng));

			// Try to fix this configuration (optimization)
			while (config.numItems < maxOutfits && config.stats.attributes[Attribute.outfitSpace] < 0 && outfitsExpansions.length)
				config.add(outfitsExpansions[$==1 ? 0 : uniform(0, $)]);
		}

		void presentConfig(ref Config config)
		{
			writeln("\n\n############################################################################################################################################\n");
			config.sort();
			printConfig(config);
			config.save("genship.json");
			createSave(`/home/vladimir/Sync-PC/saves/endless-sky/saves/Test Drive.txt`, [config]);
		}

		debug(metalog) StopWatch sw;

		bool checkResult(Score score, ref Config config)
		{
			synchronized
			{
				debug(metalog)
				{
					if (sw.running)
					{
						metaLog.writefln("%d\t%d", sw.peek.total!"hnsecs", score);
						metaLog.flush();
					}
					else
						sw.start();
				}

				if (bestScore < score)
				{
					bestScore = score;
					presentConfig(config);
					outerIterations = 0;
				}
				else
				if (outerIterations++ >= maxOuterIterations)
					return true;
				//else { write("."); stdout.flush(); }
				debug(metalog) sw.reset();
				return false;
			}
		}

		void hillClimb()
		{
			immutable maxIterations = numOutfits * numOutfits * 2;

			while (true)
			{
				Config config;
				genConfig(config);
				Score score = config.score;

				uint iterations;
				while (iterations < maxIterations)
				{
					auto newConfig = config;
					mutate(newConfig);

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

				if (checkResult(score, config))
					break;
			}
		}

		void simulatedAnnealing()
		{
			immutable simAllIterations = numOutfits * numOutfits * 2;
			immutable finalIterations  = numOutfits * numOutfits * 2;
			immutable maxIterations    = simAllIterations + finalIterations;

			while (true)
			{
				Config config;
				genConfig(config);
				Score score = config.score;

				uint iterations;
				while (iterations < maxIterations)
				{
					auto newConfig = config;
					mutate(newConfig);

					if (newConfig.isOK)
					{
						auto newScore = newConfig.score;
						bool accept;
						if (score < newScore)
							accept = true;
						else // newScore < score
							if (iterations < simAllIterations && newScore > 0)
							{
								// accept if (iterations/simAllIterations) < (newScore / score)
								accept = Value(iterations) / simAllIterations < Value(newScore) / score;
							}
							else
								accept = false;

						if (accept)
						{
							config = newConfig;
							score = newScore;
							if (iterations > simAllIterations)
								iterations = simAllIterations; // reset final stage
						}
					}
					iterations++;
				}

				if (checkResult(score, config))
					break;
			}
		}

		simulatedAnnealing();
	}

	foreach (thread; totalCPUs.iota.parallel(1))
		searchThread();
}
