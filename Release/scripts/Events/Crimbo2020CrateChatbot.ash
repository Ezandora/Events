//To use:
//set chatbotScript=Crimbo2020CrateChatbot.ash
int getSecondsSinceLastCombatStarted()
{
	//format: 20201220013603
	string in_format = "yyyyMMddkkmmssZ";
	string out_format = "";
	//string new_format = format_date_time(in_format, get_property("_lastCombatStarted"), out_format);
	//Include time zone:
	int last_fight_begin = date_to_timestamp(in_format, get_property("_lastCombatStarted") + "-0000");
	
	int now = now_to_int();
	int delta = (now - last_fight_begin) / 1000;
	if (delta < -10) //a large negative delta means our time zones are incorrect and we can't know the truth; just say the last fight was a day ago
		return 24 * 60 * 60;
	return delta;
}

void main(string sender, string message, string channel)
{
	if (message.contains_text("New message received") && channel == "Events" && !message.contains_text("The New-You Club") && !message.contains_text("The Loathing Postal Service") && getSecondsSinceLastCombatStarted() >= 60)
	{
		cli_execute("call Crimbo2020SendBackCrates.ash");
	}
}