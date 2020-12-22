/*
Crimbo2020FarmSpirit.ash
Written by Ezandora

Spreads Crimbo spirit in Seaside Town. By default, picks the spirit that is currently losing.
Also collects factory daily.
Give "help" as an argument for list of commands past that.
*/
//place.php?whichplace=town&action=town_c20spirit
//choice.php?whichchoice=1439&option=1&p=0,0
Record ArchivedEquipment
{
	item [slot] previous_equipment;
	familiar previous_familiar;
	familiar previous_enthroned_familiar;
	familiar previous_bjorned_familiar;
};

ArchivedEquipment __global_archived_equipment;

ArchivedEquipment ArchiveEquipment()
{
	ArchivedEquipment ae;
	
	foreach s in $slots[hat,weapon,off-hand,back,shirt,pants,acc1,acc2,acc3,familiar]
		ae.previous_equipment[s] = s.equipped_item();
	ae.previous_familiar = my_familiar();
	ae.previous_enthroned_familiar = my_enthroned_familiar();
	ae.previous_bjorned_familiar = my_bjorned_familiar();
	
	__global_archived_equipment = ae;
	return ae;
}


void RestoreArchivedEquipment(ArchivedEquipment ae)
{
	use_familiar(ae.previous_familiar);
	foreach s, it in ae.previous_equipment
	{
		if (s.equipped_item() != it)
		{
			if (it.available_amount() > 0)
				equip(s, it);
			else if (it == $item[none])
				equip(s, it);
		}
	}
	if ($item[crown of thrones].equipped_amount() > 0 && ae.previous_enthroned_familiar != $familiar[none])
		enthrone_familiar(ae.previous_enthroned_familiar);
	if ($item[buddy bjorn].equipped_amount() > 0 && ae.previous_bjorned_familiar != $familiar[none])
		bjornify_familiar(ae.previous_bjorned_familiar);
}

void RestoreArchivedEquipment()
{
	RestoreArchivedEquipment(__global_archived_equipment);
}


string __farm_spirit_version = "1.1.2";

boolean __setting_disable_automatics = false;
boolean __setting_one_house_only = false;
boolean __setting_enable_balance = false;
int __chosen_spirit = -1;

int SPIRIT_RANDOM = 1;
int SPIRIT_CHEER = 2;
int SPIRIT_CAROLS = 3;
int SPIRIT_COMMERCE = 4;

boolean mafiaIsPastRevision(int revision_number)
{
    if (get_revision() <= 0) //get_revision reports zero in certain cases; assume they're on a recent version
        return true;
    return (get_revision() >= revision_number);
}
float my_active_basestat(stat s)
{
	float v = my_basestat(s);
	float limit = numeric_modifier(s + " Limit");
	
	if (limit > 0 && limit < v)
		v = limit;
	if (v < 0) v = 1;
	return v;
}

stat getCurrentLargestStat()
{
	stat current_largest_stat = my_primestat();
	
	foreach s in $stats[muscle,mysticality,moxie]
	{
		if (s.my_buffedstat() > current_largest_stat.my_buffedstat())
			current_largest_stat = s;
	}
	return current_largest_stat;
}

stat getCurrentLargestStatRatio()
{
	stat best_stat_for_rewards = $stat[none];
	float best_stat_ratio = 0.0;
	
	foreach s in $stats[muscle, mysticality, moxie]
	{
		float ratio = s.my_buffedstat().to_float() / MAX(100.0, s.my_active_basestat().to_float());
		if (ratio > best_stat_ratio || best_stat_for_rewards == $stat[none])
		{
			best_stat_for_rewards = s;
			best_stat_ratio = ratio;
		}
	}
	return best_stat_for_rewards;
}

int discoverChoiceIDFromPageText(string page_text)
{
	//Same as mafia's:
	string [int] extraction_patterns;
	extraction_patterns[extraction_patterns.count()] = "name=['\"]?whichchoice['\"]? value=['\"]?(\\d+)['\"]?";
	extraction_patterns[extraction_patterns.count()] = "value=['\"]?(\\d+)['\"]? name=['\"]?whichchoice['\"]?";
	extraction_patterns[extraction_patterns.count()] = "choice.php\\?whichchoice=(\\d+)";
	foreach key, s in extraction_patterns
	{
		string [int, int] matches = page_text.group_string(s);
		if (matches.count() == 0)
			continue;
		string value = matches[0][1];
		if (!is_integer(value))
			continue;
		return value.to_int();
	}
	//Try extracting a choice.php: (witchess)
	
	string [int][int] generic_matches = page_text.group_string("\"choice.php\\?([^\" ]*)\"");
	if (generic_matches.count() > 0)
	{
		string first_level = generic_matches[0][1];
		string [int][int] second_level_matches = first_level.group_string("whichchoice=([0-9]*)");
		if (second_level_matches.count() > 0)
		{
			string value = second_level_matches[0][1];
			if (is_integer(value))
				return value.to_int();
		}
	}
	
	if (page_text.contains_text("<b>Hippy Talkin'</b>"))
		return 798;
	return -1;
}

buffer run_choice_by_text(string page_text, string identifier)
{
	identifier = identifier.replace_string("?", "\\?"); //FIXME remove/escape other grepables
	string [int][int] matches = page_text.group_string("option value=\"?([0-9]*)\"?><Table><tr><td valign=center><input [ ]*class=button type=submit value=\"" + identifier);
	//><input type=hidden name=option value=3><Table><tr><td valign=center><input class=button type=submit value="Ask for candy">
	//string [int][int] matches = page_text.group_string("choice.php.whichchoice=[0-9]*&option=([0-9]*)[^']*';[^\"]*\" value=\"" + identifier);
	int choice_id = matches[0][1].to_int();
	if (choice_id <= 0)
	{
	
		matches = page_text.group_string("option value=([0-9]*)><input [ ]*class=button type=submit value=\"" + identifier);
		choice_id = matches[0][1].to_int();
		if (choice_id <= 0)
		{
			buffer blank;
			return blank;
		}
	}
	return run_choice(choice_id);
}



void pickSpirit()
{
	if (__chosen_spirit == -1)
	{
		if (__setting_enable_balance)
		{
			buffer page_text = visit_url("place.php?whichplace=crimbo20&action=c20_abuela");
			//to_int(buffer) silently returns zero, have to convert to string first:
			int cheer_levels = page_text.group_string("<b>Cheer</b></td><td>([0123456789,]*)</td>")[0][1].replace_string(",", "").to_string().to_int();
			int carols_levels = page_text.group_string("<b>Carols</b></td><td>([0123456789,]*)</td>")[0][1].replace_string(",", "").to_string().to_int();
			int commerce_levels = page_text.group_string("<b>Commerce</b></td><td>([0123456789,]*)</td>")[0][1].replace_string(",", "").to_string().to_int();
		
			print_html("Global Cheer: " + cheer_levels + ", Carols: " + carols_levels + ", Commerce: " + commerce_levels + ", going with the least popular.");
		
		
			if (cheer_levels < carols_levels && cheer_levels < commerce_levels)
			{
				__chosen_spirit = SPIRIT_CHEER;
			}
			else if (carols_levels < cheer_levels && carols_levels < commerce_levels)
			{
				__chosen_spirit = SPIRIT_CAROLS;
			}
			else if (commerce_levels < cheer_levels &&  commerce_levels < carols_levels)
			{
				__chosen_spirit = SPIRIT_COMMERCE;
			}
			else
			{
				__chosen_spirit = random(3) + 2;
			}
		}
		else
		{
			__chosen_spirit = random(3) + 2;
		}
	}
	
	
	if (__chosen_spirit == SPIRIT_CHEER)
	{
		print("Farming with spirit Cheer.");
	}
	else if (__chosen_spirit == SPIRIT_CAROLS)
	{
		print("Farming with spirit Carols.");
	}
	else if (__chosen_spirit == SPIRIT_COMMERCE)
	{
		print("Farming with spirit Commerce.");
	}
	else if (__chosen_spirit == SPIRIT_RANDOM)
	{
		print("Farming with a random spirit.");
	}
	else
	{
		__chosen_spirit = SPIRIT_RANDOM;
		print("Farming with a random spirit.");
	}
	
	
}
void prepareForSpiritFirst()
{
	if (__setting_disable_automatics) return;
	//cli_execute("maximize 1 muscle 1 mysticality 1 mainstat -tie");
	
	if (__chosen_spirit == SPIRIT_CHEER)
	{
		familiar ghost = to_familiar("Ghost of Crimbo Cheer");
		if (ghost != $familiar[none] && ghost.have_familiar())
		{
			use_familiar(ghost);
		}
	}
	else if (__chosen_spirit == SPIRIT_CAROLS)
	{
		familiar ghost = to_familiar("Ghost of Crimbo Carols");
		if (ghost != $familiar[none] && ghost.have_familiar())
		{
			use_familiar(ghost);
		}
	}
	else if (__chosen_spirit == SPIRIT_COMMERCE)
	{
		familiar ghost = to_familiar("Ghost of Crimbo Commerce");
		if (ghost != $familiar[none] && ghost.have_familiar())
		{
			use_familiar(ghost);
		}
	}
	
	//Hmm...
	//Just maximise our largest stat. (not primestat, because if they have rhinestones active, we should respond to that)
	
	/*float muscle_score = maximize("muscle -tie", 0, 0, false, true);
	float mysticality_score = maximize("mysticality -tie", 0, 0, false, true);
	float moxie_score = maximize("moxie -tie", 0, 0, false, true);*/
	
	
	string maximisation_extras;
	
	//Need more spading, but for now we'll equip a stat limiter for 100.
	boolean ignore = cli_execute("outfit birthday suit"); //starting off with
	if (my_basestat($stat[muscle]) > 100 || my_basestat($stat[mysticality]) > 100 || my_basestat($stat[moxie]) > 100)
	{
		foreach it in $items[PARTY HARD T-Shirt, FantasyRealm G. E. M., Personal Ventilation Unit, warbear hoverbelt, Drip harness]
		{
			if (it.available_amount() > 0 && it.can_equip())
			{
				boolean ignore2 = equip(it);
				maximisation_extras += " +equip " + it;
				break;
			}
		}
	}
	//Crimbo smile
	//Book of Old-Timey Carols
	//SalesCo sample kit
	if (__chosen_spirit == SPIRIT_CHEER && to_item("Crimbo smile").available_amount() > 0 && to_item("Crimbo smile") != $item[none])
	{
		maximisation_extras += " +equip Crimbo smile";
	}
	else if (__chosen_spirit == SPIRIT_CAROLS && to_item("Book of Old-Timey Carols").available_amount() > 0 && to_item("Book of Old-Timey Carols") != $item[none])
	{
		maximisation_extras += " +equip Book of Old-Timey Carols";
	}
	else if (__chosen_spirit == SPIRIT_COMMERCE && to_item("SalesCo sample kit").available_amount() > 0 && to_item("SalesCo sample kit") != $item[none])
	{
		maximisation_extras += " +equip SalesCo sample kit";
	}
	cli_execute("maximize " + getCurrentLargestStatRatio() + maximisation_extras + " -tie");
	
	
}

void prepareForSpirit(int houses_left)
{
	if (houses_left < 1) houses_left = 1;
	if (houses_left >= 30) houses_left = 30;
	
	if (__setting_disable_automatics) return;
	
	if (!mafiaIsPastRevision(20573))
		visit_url("main.php"); //we have to do this to convince mafia we aren't in a choice adventure
	//string gain_command = "gain 10000000 muscle 10000000 moxie 10000000 mysticality 3 eff " + houses_left + " turns";
	
	//Just increase the largest stat ratio:
	
	if (__setting_one_house_only)
		houses_left = 1;
	string gain_command = "gain 10000000 " + getCurrentLargestStatRatio() + " 3 eff " + (houses_left + 1) + " turns silent limited";
	boolean success = cli_execute(gain_command);
}

void runHouses()
{
	buffer page_text;
	int breakout = 120;
	int coordinates_left = 30;
	while (breakout > 0)
	{
		breakout -= 1;
		
		if (my_adventures() == 0)
		{
			print("Out of adventures, stopping.");
			return;
		}
		if (page_text.length() == 0)
			page_text = visit_url("place.php?whichplace=town&action=town_c20spirit");
		
		
		int current_choice_id = page_text.discoverChoiceIDFromPageText();
		if (current_choice_id == 1439)
		{
			string [int][int] coordinate_matches = page_text.group_string("\"hidden\" name=\"p\" value=\"([^\"]*)\">");
		
			string target_coordinate = coordinate_matches[0][1];
		
			if (coordinate_matches.count() == 0 || target_coordinate == "")
			{
				print("No more houses.");
				break;
			}
		
			coordinates_left = coordinate_matches.count();
			print("");
			print(coordinates_left + " houses left.");
			prepareForSpirit(coordinates_left);
			page_text = visit_url("choice.php?whichchoice=1439&option=1&p=" + target_coordinate);
		}
		else if (current_choice_id == 1440)
		{
		
			//Choice 1:
			//Share a Random Spirit
			//Spread Cheer
			//Sing Carols
			//Encourage Commerce
		
			string selected_choice_1 = "Share a Random Spirit";
		
			if (__chosen_spirit == SPIRIT_RANDOM)
			{
				selected_choice_1 = "Share a Random Spirit";
			}
			else if (__chosen_spirit == SPIRIT_CHEER)
			{
				selected_choice_1 = "Spread Cheer";
			}
			else if (__chosen_spirit == SPIRIT_CAROLS)
			{
				selected_choice_1 = "Sing Carols";
			}
			else if (__chosen_spirit == SPIRIT_COMMERCE)
			{
				selected_choice_1 = "Encourage Commerce";
			}
		
			page_text = page_text.run_choice_by_text(selected_choice_1);
			if (page_text.length() == 0)
			{
				print("Unable to run choice " + selected_choice_1 + ", stopping.", "red");
				break;
			}
		}
		else if (current_choice_id == 1441)
		{
			//Choice 2:
			//Ask for food
			//Ask for booze
			//Ask for candy.
		
			//Choice 2's result gives the intro house text.
		
			string [int][int] choice_2_matches = page_text.group_string("\"Ask for ([^\"]*)\"></td><td valign=center><font color=blue><b>\\[Improved by ([^\\]]*)\\]</b>");
		
			string [int] choice_2_choices = {"Ask for food", "Ask for booze", "Ask for candy"};
			string target_choice = choice_2_choices[random(choice_2_choices.count())];
		
			//stat current_largest_stat = getCurrentLargestStat();
			stat best_stat_for_rewards = getCurrentLargestStatRatio();

			foreach key in choice_2_matches
			{
				string consumable_type = choice_2_matches[key][1];
				stat stat_type = choice_2_matches[key][2].to_stat();
				//print_html(consumable_type + " matches to " + stat_type);
				if (stat_type == best_stat_for_rewards)
				{
					print("Picking " + consumable_type + " for " + stat_type);
					target_choice = "Ask for " + consumable_type;
				}
			}
		
		
		
		
			page_text = page_text.run_choice_by_text(target_choice);
			if (page_text.length() == 0)
			{
				print("Unable to run choice " + target_choice + ", stopping.", "red");
				break;
			}
		
			if (__setting_one_house_only) break;
		}
		else
		{
			print("Currently in an unknown place, stopping.", "red");
			break;
		}
	}
}

boolean parseArguments(string arguments)
{
	string [int] words = arguments.to_lower_case().split_string(" ");
	foreach key, word in words
	{
		if (word == "") continue;
		
		
		
		if (word == "carol" || word == "carols" || word == "drink" || word == "drinks" || word == "booze")
		{
			print_html("Carols spirit chosen.");
			__chosen_spirit = SPIRIT_CAROLS;
		}
		else if (word == "cheer" || word == "food")
		{
			print_html("Cheer spirit chosen.");
			__chosen_spirit = SPIRIT_CHEER;
		}
		else if (word == "money" || word == "commerce" || word == "candy")
		{
			print_html("Commerce spirit chosen.");
			__chosen_spirit = SPIRIT_COMMERCE;
		}
		else if (word == "random")
		{
			print_html("Random spirit chosen.");
			__chosen_spirit = SPIRIT_RANDOM;
		}
		else if (word == "balance")
		{
			print_html("Balance voting chosen.");
			__setting_enable_balance = true;
		}
		else if (word == "manual" || word == "nobuff")
		{
			print_html("Disabling buffing.");
			__setting_disable_automatics = true;
		}
		else if (word == "once" || word == "one" || word == "vasili")
		{
			print_html("One house only.");
			__setting_one_house_only = true;
		}
		else if (word == "help")
		{
			print_html("Crimbo2020FarmSpirit.ash v" + __farm_spirit_version);
			print_html("");
			print_html("Spreads spirit in Crimbo Town. By default, spreads the type of spirit that is currently losing on the leaderboard. Wouldn't want it to be unfair, right?");
			print_html("");
			print_html("Options:");
			print_html("<b>cheer</b> - spread cheer (potential reward: food-giving item)");
			print_html("<b>carol</b> - spread carols (potential reward: drinks-giving item)");
			print_html("<b>commerce</b> - spread commerce (potential reward: candy-giving item)");
			print_html("<b>balance</b> - votes for the losing candidate, like previous versions of this script.");
			print_html("<b>manual</b>/<b>nobuff</b> - Disables the script changing equipment and buffing for effects.");
			print_html("<b>once</b> - One house only. (testing purposes)");
			return true;
		}
	}
	
	return false;
}

void main(string arguments)
{
	ArchivedEquipment ae = ArchiveEquipment();
	
	//Collect daily:
	visit_url("place.php?whichplace=crimbo20&action=c20_factory");
	
	//visit the secrets, because they are missable
	int secret_id = gameday_to_int() + 1;
	visit_url("place.php?whichplace=crimbo20&action=c20_secret" + secret_id);
	//place.php?whichplace=crimbo20&action=c20_secret1
	//place.php?whichplace=crimbo20&action=c20_secret2
	
	
	boolean [item] tracking_items;
	foreach s in $strings[donated booze, donated candy, donated food]
	{
		item it = s.to_item();
		if (it != $item[none])
			tracking_items[it] = true;
	}
	int [item] starting_item_amount;
	foreach it in tracking_items
		starting_item_amount[it] = it.item_amount();
	
	boolean stop = parseArguments(arguments);
	if (stop) return;
	pickSpirit();
	prepareForSpiritFirst();
	runHouses();
	if (!mafiaIsPastRevision(20573))
		visit_url("main.php"); //not in a choice adventure
	ae.RestoreArchivedEquipment();
	
	
	int [item] delta_item_amount;
	print_html("");
	foreach it in tracking_items
	{
		int delta = it.item_amount() - starting_item_amount[it];
		
		if (delta > 0)
		{
			print_html("Gained " + delta + " " + it);
		}
	}
}