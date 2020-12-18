//To use:
//set chatbotScript=Crimbo2020CrateChatbot.ash

void main(string sender, string message, string channel)
{
	if (message.contains_text("New message received") && channel == "Events" && !message.contains_text("The New-You Club") && !message.contains_text("The Loathing Postal Service"))
	{
		cli_execute("call Crimbo2020SendBackCrates.ash");
	}
}