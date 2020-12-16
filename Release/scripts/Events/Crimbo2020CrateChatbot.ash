//To use:
//set chatbotScript=Crimbo2020CrateChatbot.ash

void main(string sender, string message, string channel)
{
	if (message.contains_text("New message received") && channel == "Events")
	{
		cli_execute("call Crimbo2020SendBackCrates.ash");
	}
}