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

   //as per the slides
   void payload(pack *payloadP);

   void floodingHeader(uint16_t floodSource, uint16_t sequence, uint16_t timeToLive );

   void linkLayerHeader(uint16_t sourceAdress, uint16_t destinationAdress);


   void sendWithTimerPing(pack *package);
   void sendWithTimerDiscovery(pack package, uint16_t destination);

   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");
   }


   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");

         call Timer0.startPeriodic(1000);                     
      }else{
         call AMControl.start();                                            
      }
   }

   event void AMControl.stopDone(error_t err){}

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){

      dbg(GENERAL_CHANNEL, "Packet Received\n");

       if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);

         call Sender.send(sendPackage, AM_BROADCAST_ADDR);



         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;




}