/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"


typedef nx_struct floodingLayer{
   nx_uint16_t floodSource;
   nx_uint16_t sequenceNumber;
   nx_uint16_t TTL;

}floodingLayer;

typedef nx_struct linkLayer{
   nx_uint16_t sourceAddress;
   nx_uint16_t destinationAdress;
  

}linkLayer;
//application payload: payload is in the packgare



typedef nx_struct Nod{
  typedef nx_struct Nod *floodingLayer;
  typedef nx_struct Nod *linkLayer;
   

}Nod;


module Node{
   uses interface Boot;
   uses interface Random as RandomTimer; 
   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   uses interface Timer<TMilli> as NeighboorTimer;
   uses interface List<pack> as NeighboorList;


   
}

implementation{
   pack sendPackage;
   uint16_t seqNumber;


   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   void printNeighboorList();
   void neighboorDiscovery();



   event void Boot.booted(){
     uint16_t start;
      call AMControl.start();
    

      dbg(GENERAL_CHANNEL, "Booted\n");
       start = call RandomTimer.rand16();

      call NeighboorTimer.startPeriodicAt(0,start);

      //Fire timers
      dbg(GENERAL_CHANNEL,"Neigboor Timer started at %d \t being shot every: %d \t",0,start);

   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      dbg(GENERAL_CHANNEL, "Packet Received\n");


      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);


         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, 0, 0, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage, destination);
   }

   event void CommandHandler.printNeighbors(){}

   event void CommandHandler.printRouteTable(){}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}



   event void NeighboorTimer.fired()
   {
      neighboorDiscovery();
   }
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol; 
      memcpy(Package->payload, payload, length);
   }

   void neighboorDiscovery()
   {
 //dbg(GENERAL_CHANNEL, "in neighboor discovery\n");

   }

   
}
