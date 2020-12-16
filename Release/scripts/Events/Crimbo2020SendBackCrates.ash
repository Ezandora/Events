
/*
Crimbo2020SendBackCrates.ash


Settings:

Run this to always attempt sending back crates, even if we did today. (not a good choice)
set ezandoraCrimbo2020DoNotIgnoreAlreadySentBackKmails=true

Run this to delete kmails sent to us. Warning: dangerous.
set ezandoraCrimbo2020DeleteKmails=true

Run this to save kmails sent to us. Might be a nightmare.
set ezandoraCrimbo2020SaveKmails=true
*/



string __send_back_crates_version = "1.1";

boolean [string] __already_processed_kmails;


//If you try to respond to a kmail and you already sent for today, just ignore it.
//This is 
boolean __setting_ignore_already_sent_back_kmails = !get_property("ezandoraCrimbo2020DoNotIgnoreAlreadySentBackKmails").to_boolean();
boolean __setting_extremely_dangerous_delete_responded_to_kmails = get_property("ezandoraCrimbo2020DeleteKmails").to_boolean(); //do not enable unless you trust the script
boolean __setting_save_responded_to_kmails = get_property("ezandoraCrimbo2020SaveKmails").to_boolean();
int __setting_kmail_load_limit = 100;


string __processed_kmails_datafile = "ezandora_crimbo2020_send_back_crates_" + my_id() + ".txt";
void loadProcessedKMails()
{
	file_to_map(__processed_kmails_datafile, __already_processed_kmails);
}

void saveProcessedKMails()
{
	map_to_file(__already_processed_kmails, __processed_kmails_datafile);
}

Record KMail
{
	string id;
	string type;
	string fromid;
	string azunixtime;
	string message;
	string fromname;
	string localtime;
};

KMail [int] KMailGetAllKMails()
{
	buffer kmail_text = visit_url("api.php?what=kmail&count=" + __setting_kmail_load_limit + "&for=ezandora_crimbo2020_crates");
	
	buffer processing_text = kmail_text.replace_string("\\\"", "•"); //parsing hack
	
	string [int][int] kmail_matches = kmail_text.group_string("\\{\"id\":\"([^\"]*)\",\"type\":\"([^\"]*)\",\"fromid\":\"([^\"]*)\",\"azunixtime\":\"([^\"]*)\",\"message\":\"([^\"]*)\",\"fromname\":\"([^\"]*)\",\"localtime\":\"([^\"]*)\"}"); //forgive me, father, for I have sinned
	KMail [int] kmails;
	foreach key in kmail_matches
	{
		string [int] line = kmail_matches[key];
		KMail k;
		k.id = line[1];
		k.type = line[2];
		k.fromid = line[3];
		k.azunixtime = line[4];
		k.message = line[5].replace_string("•", "\\\"");
		k.fromname = line[6];
		k.localtime = line[7];
		kmails[kmails.count()] = k;
	}
	return kmails;
}

void KMailSaveKMail(KMail k)
{
	string command = "messages.php?the_action=save&box=Inbox";
	command += "&sel" + k.id + "=on";
	visit_url(command);
}
void KMailDeleteKMail(KMail k)
{
	string command = "messages.php?the_action=delete&box=Inbox";
	command += "&sel" + k.id + "=on";
	visit_url(command);
}



boolean stringHasAllSubstrings(string v, string [int] substrings)
{
	foreach key, matching_string in substrings
	{
		if (!v.contains_text(matching_string))
			return false;
	}
	return true;
}

void main()
{
	loadProcessedKMails();
	KMail [int] kmails = KMailGetAllKMails();
	
	 //"has sent you a shipment of food!<center><table class=\"item\" style=\"float: none\" rel=\"id=9663&s=0&q=0&d=0&g=0&t=0&n=50&m=0&p=0&u=.\"><tr><td><img src=\"https:\/\/s3.amazonaws.com\/images.kingdomofloathing.com\/itemimages\/donatedfood.gif\" alt=\"donated food\" title=\"donated food\" class=hand onClick='descitem(940575506)' ><\/td><td valign=center class=effect>You acquire <b>50 piles of donated food<\/b><\/td><\/tr><\/table><\/center>";
	string [int] food_shipment_strings =  {"has sent you a shipment of food!<center>",  "onClick='descitem(940575506)' >", "You acquire <b>50 piles of donated food"};
	string [int] booze_shipment_strings = {"has sent you a shipment of booze!<center>", "onClick='descitem(803482456)' >", "You acquire <b>50 boxes of donated booze"};
	string [int] candy_shipment_strings = {"has sent you a shipment of candy!<center>", "onClick='descitem(442893531)' >", "You acquire <b>50 boxes of donated candy"};
	
	
	boolean disable_sending = false;
	int [string] totals_needed;
	boolean halt = false;
	foreach key, k in kmails
	{
		if (k.fromid <= 0) continue;
		if (__already_processed_kmails[k.id])
		{
			if (__setting_extremely_dangerous_delete_responded_to_kmails)
				KMailDeleteKMail(k);
			if (__setting_save_responded_to_kmails)
				KMailSaveKMail(k);
			continue;
		}
		
		int whichitem = -1;
		int whichchoice = -1;
		string shipment_item_name = "";
		if (stringHasAllSubstrings(k.message, food_shipment_strings))
		{
			print(k.fromname + " sent us food.");
			whichitem = 10685;
			whichchoice = 1442;
			shipment_item_name = "government food shipment";
		}
		else if (stringHasAllSubstrings(k.message, booze_shipment_strings))
		{
			print(k.fromname + " sent us booze.");
			whichitem = 10686;
			whichchoice = 1443;
			shipment_item_name = "government booze shipment";
		}
		else if (stringHasAllSubstrings(k.message, candy_shipment_strings))
		{
			print(k.fromname + " sent us candy.");
			whichitem = 10687;
			whichchoice = 1444;
			shipment_item_name = "government candy shipment";
		}
		else
			continue;
		if (whichitem == -1 || whichchoice == -1) continue;
		if (disable_sending)
		{
			totals_needed[shipment_item_name] += 1;
			continue;
		}
		print("Responding...");
		buffer use_page_results = visit_url("inv_use.php?whichitem=" + whichitem);
		if (!use_page_results.contains_text("Send a shipment of government"))
		{
			print("We cannot respond right now; buy a " + shipment_item_name);
			totals_needed[shipment_item_name] += 1;
			disable_sending = true;
			continue;
		}
		
		boolean success = false;
		buffer send_results = visit_url("choice.php?whichchoice=" + whichchoice + "&option=1&who=" + k.fromid);
		if (send_results.contains_text("You fill out all the appropriate forms and send the"))
		{
			success = true;
			print("Sent " + shipment_item_name + " to " + k.fromname + ".");
		}
		else if (send_results.contains_text("You already sent that player a crate"))
		{
			print("Unable to send to " + k.fromname + ", already sent today.");
			if (__setting_ignore_already_sent_back_kmails)
			{
				__already_processed_kmails[k.id] = true;
				saveProcessedKMails();
			}
		}
		else
		{
			if (my_id() == 1557284)
				print_html("send_results = " + send_results.entity_encode());
			print("Unknown error sending shipment to " + k.fromname + ", halting.");
			halt = true;
		}
		if (success)
		{
			if (__setting_extremely_dangerous_delete_responded_to_kmails)
				KMailDeleteKMail(k);
			if (__setting_save_responded_to_kmails)
				KMailSaveKMail(k);
			__already_processed_kmails[k.id] = true;
			saveProcessedKMails();
		}
		else
		{
			buffer results_3 = visit_url("choice.php?whichchoice=" + whichchoice + "&option=1&who=");
		}
		
		if (halt) break;
	}
	
	string line;
	if (totals_needed.count() > 0)
	{
		line = "You will need a total of ";
		boolean first = true;
		foreach item_name, amount in totals_needed
		{
			if (!first)
				line += ",";
			line += " " + amount + " " + item_name;
			first = false;
		}
		line += ".";
		print(line);
		print("Remember to use sleaze jelly (multi-buy) and Travoltan trousers.");
	}
	print_html("Done processing crates.");
}