#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"

module Node{
	
	uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

     uses interface SimpleSend as Sender;
   uses interface CommandHandler;

   uses interface List<Neighboor> as neighborList;
   uses interface List<pack> as packetList;
   uses interface Timer<Tmilli> as tTimerl 
}