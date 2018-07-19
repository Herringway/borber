import siryul;

import std.algorithm;
import std.format;
import std.math;
import std.stdio;

struct Config {
	uint totalDraws;
	uint mythrilCost;
	uint guaranteedWins;
	Group[] groups;
	SubDivision[] subDivisions;
	double odds;
	double cutoff;
}
struct Group {
	string name;
	Item[] items;
}
struct Item {
	string name;
	ulong count;
}
struct SubDivision {
	string name;
	double odds = 0.0;
}
struct RollResult {
	uint wins;
	double chance;
}
struct AllRollResults {
	RollResult[] results;
	double mean = 0.0;
	double standardDeviation = 0.0;
}
void main(string[] args) {
	string file = "cfg.yml";
	if (args.length > 1) {
		file = args[1];
	}
	auto conf = fromFile!(Config, YAML)(file);
	writefln!"Number of draws: %s"(conf.totalDraws);
	writefln!"Mythril cost: %s"(conf.mythrilCost);
	writefln!"Chance of drawing 5* or better: %3.1f%%"(conf.odds*100);
	writefln!"Number of guaranteed successes: %s"(conf.guaranteedWins);
	writefln!"Not showing chances less than %3.1f%%"(conf.cutoff*100);
	foreach (group; conf.groups) {
		ulong total = group.items.map!(x => x.count).sum;
		foreach (item; group.items) {
			conf.subDivisions ~= SubDivision(item.name, cast(double)item.count/total);
		}
	}
	SubDivision[][] overallSubDivisions;
	foreach (i, subdiv; conf.subDivisions) {
		overallSubDivisions ~= new SubDivision[](conf.totalDraws+1);
	}
	foreach (subdiv; conf.subDivisions) {
		writefln!"Chances of %s per success: %3.1f%%"(subdiv.name, subdiv.odds*100);
	}
	auto results = doRolls(conf.totalDraws-conf.guaranteedWins, conf.guaranteedWins, conf.odds);
	bool printRest;
	ulong lastPrint = 1;
	double cumulative = 0.0;
	foreach (result; results.results) {
		if (result.chance >= conf.cutoff) {
			lastPrint++;
			writefln!"%s/%s - %3.1f%%"(result.wins, conf.totalDraws, result.chance * 100);
		} else {
			printRest = true;
			cumulative += result.chance;
		}
		if (result.wins > 0) {
			foreach (i, subdiv; conf.subDivisions) {
				auto subRolls = doRolls(result.wins, 0, subdiv.odds);
				foreach (res; subRolls.results) {
					if ((res.chance > conf.cutoff) && (result.chance > conf.cutoff)) {
						writefln!"\t - %-20 s - %-2s/%-2s - %3.1f%%"(subdiv.name, res.wins, result.wins, res.chance*100);
					}
					overallSubDivisions[i][res.wins].odds += res.chance*result.chance;
				}
				if (result.chance > conf.cutoff) {
					//writefln!"\t - %-20 s - StdDev - %s"(subdiv.name, subRolls.standardDeviation);
					writefln!"\t - %-20 s - Mean   - %s"(subdiv.name, subRolls.mean);
				}
			}
		}
	}
	if (printRest) {
		writefln!"%s+/%s - %3.1f%%"(lastPrint, conf.totalDraws, cumulative*100);
	}
	foreach (i, subdiv; overallSubDivisions) {
		if (subdiv[0].odds == 1.0) {
			continue;
		}
		cumulative = 0.0;
		printRest = false;
		lastPrint = 0;
		writefln!"%s:"(conf.subDivisions[i].name);
		foreach (j, res; subdiv) {
			if ((j == 0) || (res.odds >= conf.cutoff)) {
				lastPrint = j+1;
				writefln!"\t%-3 s: %3.1f%%"(j, res.odds*100);
			} else {
				printRest = true;
				cumulative += res.odds;
			}
		}
		if (printRest) {
			writefln!"\t%-2 s+: %3.1f%%"(lastPrint, cumulative*100);
		}
	}
	//writefln!"StdDev - %s"(results.standardDeviation);
	writefln!"Mean   - %s"(results.mean);
	writefln!"Relics per mythril: %s"(results.mean / cast(double)conf.mythrilCost);
}

AllRollResults doRolls(int x, int wins, double odds) {
	auto result = AllRollResults();
	double[] stdDevParts;
	foreach (i; 0..x+1) {
		double chance = cast(double)coefficient(x, i) * odds^^i * (1.0-odds)^^(x-i);
		result.results ~= RollResult(wins+i, chance);
		result.mean = result.mean + chance * (i + wins);
		stdDevParts ~= chance * i;
	}
	foreach (stdDev; stdDevParts) {
		result.standardDeviation += (stdDev - result.mean) ^^ 2.0;
	}
	result.standardDeviation /= x+1.0;
	result.standardDeviation = sqrt(result.standardDeviation);
	return result;
}

uint coefficient(uint n, uint r) {
	uint nCr = 1;
	foreach (r_; 0..r) {
		nCr = nCr * (n-r_) / (r_+1);
	}
	return nCr;
}
