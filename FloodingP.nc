#include <Timer.h>
#include "includes/channels.h"
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"


module Node
{
	uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   //declaring timer
   uses interface Timer<TMilli> as Timer0;

   //declaring interfaces. Interfaces are in DataStructures/interfaces/List
   uses interface List<Neighbor> as NeighborList;
   uses interface List<Flood> as FloodingList;


 
	
}
implementation{
	
	//Declaration of Variables
	pack sendPackage;
	uint16_t sequenceNumber=0;

	// Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");
   }


   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");

         call perTimer.startPeriodic(1000);                     
      }else{
         call AMControl.start();                                            
      }
   }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      dbg(GENERAL_CHANNEL, "Packet Received\n");




}