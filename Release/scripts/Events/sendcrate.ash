

void runCrate(int whichitem, int whichchoice, string target_player, string crate_name)
{
	buffer use_page_results = visit_url("inv_use.php?whichitem=" + whichitem);
	if (!use_page_results.contains_text("Send a shipment of government"))
	{
		print_html("Missing crate " + crate_name);
		return;
	}
	buffer send_results = visit_url("choice.php?whichchoice=" + whichchoice + "&option=1&who=" + target_player);
	
	if (send_results.contains_text("You fill out all the appropriate forms and send the"))
	{
		print("Sent " + crate_name + " to " + target_player);
	}
	else if (send_results.contains_text("You already sent that player a crate"))
	{
		print("Already sent " + crate_name + " to " + target_player);
	}
	else if (send_results.contains_text("Can't find that player."))
	{
		print("Can't find target player " + target_player);
	}
	else if (send_results.contains_text("You can't send it to yourself."))
	{
		print("Can't let you send crates to yourself, Star" + my_name() + ".");
	}
	else
	{
		//print_html(send_results.entity_encode());
		print("Unknown event trying to send " + crate_name + " to " + target_player);
		buffer results_3 = visit_url("choice.php?whichchoice=" + whichchoice + "&option=1&who=");
	}
}

void main(string target_player)
{
	print_html("Sending crates to " + target_player);
	runCrate(10685,1442, target_player, "government food shipment");
	runCrate(10686,1443, target_player, "government booze shipment");
	runCrate(10687,1444, target_player, "government candy shipment");
}