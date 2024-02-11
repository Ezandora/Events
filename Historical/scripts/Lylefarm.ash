//Farms dust bunnies and stock certificates for Lyle, Traveling Infrastructure Specialist.
//This script is in the public domain.
//Written by Ezandora.

string __lyle_version = "1.2.3";

boolean run_choice_by_text(string page_text, string identifier)
{
	foreach s in $strings[?,(,)]
		identifier = identifier.replace_string(s, "\\" + s); //FIXME remove/escape other grepables
	string [int][int] matches = page_text.group_string("value=\"?([0-9]*)\"?><input [ ]*class=button type=submit value=\"" + identifier);
	int choice_id = matches[0][1].to_int();
	if (choice_id <= 0)
		return false;
	run_choice(choice_id);
	return true;
}


void reachFarmingPage()
{
	//visit_url("place.php?whichplace=town_right&action=townright_lyle");
	if (true)
		return;
	int breakout = 20;
	while (breakout > 0)
	{
		breakout -= 1;
		buffer page_text = visit_url("choice.php");
		//if (page_text.contains_text("All you need is ten thousand meat and a dream"))
		if (page_text.contains_text("and a dream") && page_text.contains_text("is ten thousand")) //Awl ewe knead is ten thousand meet and a dream!
		{
			//print_html("Reached farming page.");
			return;
		}
		
		if (run_choice_by_text(page_text, "Ok, ok, skip to the good part"))
			continue;
		if (run_choice_by_text(page_text, "What'll you call it when it's done?"))
			continue;
		if (run_choice_by_text(page_text, "That sounds good, I'll buy if I'm able!"))
			continue;
		if (run_choice_by_text(page_text, "That idea sure sounds whack!"))
			continue;
		if (run_choice_by_text(page_text, "That sounds neat, but where will it go?"))
			continue;
		if (run_choice_by_text(page_text, "Why wouldn't I just drive a car?"))
			continue;
		if (run_choice_by_text(page_text, "Now, this sounds great, what it called?"))
			continue;
		if (run_choice_by_text(page_text, "Stock you say, you're here to hock?"))
			continue;
		if (run_choice_by_text(page_text, "10,000 Meat?  Well that seems fair"))
			continue;
		abort("Unable to help, stopping.");
	}
}

void escapeLyle()
{
	int breakout = 5;
	while (breakout > 0)
	{
		breakout -= 1;
		buffer page_text = visit_url("choice.php");
		run_choice_by_text(page_text, "Maybe later");
		run_choice_by_text(page_text, "I'm not really afraid, but this is taking FOREVER!");
		if (page_text.contains_text("pocketbook") && page_text.contains_text("get it from Hagnk"))
		{
			run_choice_by_text(page_text, "0 Meat");
		}
		else if (page_text.contains_text("Sorry, Bud, this plan"))
		{
			run_choice_by_text(page_text, "Sorry, Bud, this plan seems unstable.");
		}
		else if (page_text.contains_text("refurbishing this old building by the train yard"))
		{
			run_choice_by_text(page_text, "Uh, no thanks.");
		}
	}
}

void main(int adventures_to_use)
{
	int adventures_per_john_henry = 1;
	//if (adventures_to_use > 11) adventures_to_use = 11;
	print_html("Lylefarm version " + __lyle_version + ".");
	if (my_adventures() < adventures_per_john_henry)
	{
		print_html("<font color=\"red\">Need at least eleven adventures to farm this absolutely legitimate and worthwhile stock.</font>");
		return;
	}
	if (adventures_to_use < adventures_per_john_henry)
	{
		print_html("<font color=\"red\">Specify at least eleven adventures to farm this absolutely legitimate and worthwhile stock.</font>");
		return;
	}
	if ($item[drunkula's wineglass].equipped_amount() == 0 && my_inebriety() > inebriety_limit()) //'
	{
		print_html("<font color=\"red\">You are drunk.</font>");
		return;
	}
	
	slot next_slot = $slot[acc1];
	foreach it in $items[mafia organizer badge,worksite credentials]
	{
		if (it.equipped_amount() == 0 && it.available_amount() > 0 && it.can_equip())
		{
			equip(next_slot, it);
			if (next_slot == $slot[acc1])
				next_slot = $slot[acc2];
			else
				next_slot = $slot[acc3];
		}
	}
	
	
	visit_url("place.php?whichplace=town_right&action=townright_lyle");
	run_choice_by_text(visit_url("choice.php"), "&quot;No Thanks.&quot;");
	boolean [item] relevant_items;
	relevant_items[to_item("L.I.M.P. Stock Certificate")] = true;
	relevant_items[to_item("dust bunny")] = true;
	relevant_items[to_item("shovelful of dirt")] = true;
	relevant_items[to_item("hunk of granite")] = true;
	int [item] amount_before;
	foreach it in relevant_items
		amount_before[it] = it.item_amount();
	reachFarmingPage();
	int breakout = 300;
	boolean should_shovel_next = false;
	if (random(2) == 0)
		should_shovel_next = true;
	while (my_adventures() >= adventures_per_john_henry && adventures_to_use >= adventures_per_john_henry && breakout > 0)
	{
		breakout -= 1;
		/*buffer page_text = visit_url("choice.php");
		if (!page_text.contains_text("Work a shovel?"))
		{
			break;
		}
		
		//print_html("page_text = " + page_text.entity_encode());
		if (should_shovel_next)
			run_choice_by_text(page_text, "Work a shovel? (11 adventures)");
		else
			run_choice_by_text(page_text, "Work a sledgehammer? (11 adventures)");
		should_shovel_next = !should_shovel_next;*/
		buffer page_text = visit_url("adventure.php?snarfblat=496");
		visit_url("main.php");
		run_combat();
		
		if (page_text.length() == 0 || page_text.contains_text("regulations prevent you from spending any more time at the work site"))
			break;
		
		adventures_to_use -= adventures_per_john_henry;
	}
	escapeLyle();
	print_html("");
	string file_name = "lylefarm_stage_2_" + my_id() + ".txt";
	int [item] file_archive;
	file_to_map(file_name, file_archive);
	
	
	//just in case these start existing to us:
	relevant_items[to_item("shovelful of dirt")] = true;
	relevant_items[to_item("hunk of granite")] = true;
	foreach it in relevant_items
	{
		int delta = it.item_amount() - amount_before[it];
		if (delta > 0)
		{
			print("Collected " + delta + " " + (delta > 1 ? it.plural : it) + ".");
			file_archive[it] += delta;
		}
	}
	map_to_file(file_archive, file_name);
	
	string line = "";
	int bunnies_archive = file_archive[to_item("dust bunny")];
	if (bunnies_archive > 0)
	{
		int certificates_archive = file_archive[to_item("L.I.M.P. Stock Certificate")];
		float rate = to_float(bunnies_archive) / to_float(certificates_archive);
		print("Historical: farmed " + certificates_archive + " certificates and " + bunnies_archive + " bunnies. Rate of " + (round(rate * 1000.0) / 10.0) + "%.");
	}
	
	if (to_item("dust bunny").item_amount() > 0 && hippy_stone_broken()) //protect ourselves from PVP
		cli_execute("closet put * dust bunny");
	print_html("Done.");
}