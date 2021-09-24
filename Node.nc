/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 * 
 */ 
#include <Timer.h>
#include "command.h"
#include "packet.h"
#include "sendInfo.h"
#include "ping.h"

typedef nx_struct neighbor {
   nx_uint16_t Node;
   nx_uint8_t Age;
}neighbor;

module Node{
   uses interface Boot;

   uses interface List<pack> as PacketList;
   uses interface Random as Random;
   uses interface SplitControl as AMControl;
   uses interface Receive;
   uses interface Timer<TMilli> as PeriodicTimer;
   uses interface List<neighbor *> as NeighborList;
   uses interface Pool<neighbor> as NeighborPool;

   uses interface SimpleSend as Sender;
}

implementation{
   pack sendPackage;
   uint16_t seqCounter = 0;
   uint16_t firedCounter = 0;


   // Prototypes
   bool findPack(pack *Package);
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   void pushPack(pack Package);
   void discoverNeighborList();
   void printNeighborList();
 
   event void Boot.booted(){
      uint32_t start, offset;
      uint16_t add;
      call AMControl.start();
      //dbg("genDebug", "Booted\n");
      start = call Random.rand32() % 2000;
      add = call Random.rand16() % 2;
      //randomize firing period
      if(add == 1) {
         offset = 15000 + (call Random.rand32() % 5000);
      } else {
         offset = 15000 - (call Random.rand32() % 5000);
      }
      call PeriodicTimer.startPeriodicAt(start, offset);
      dbg("Project1N", "Booted with periodic timer starting at %d, firing every %d\n", start, offset);
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg("genDebug", "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event void PeriodicTimer.fired() {
      discoverNeighborList();
   }

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      //dbg("genDebug", "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;

         //Check the packet first to see if we've seen it before
         if(myMsg->TTL == 0 || findPack(myMsg)) {
            //Drop the packet if we've seen it or if it's TTL has run out: i.e. do nothing
            //dbg("Project1F", "Dropping packet seq#%d from %d\n", myMsg->seq, myMsg->src);           
         } else if(myMsg->dest == AM_BROADCAST_ADDR) {
            //Handle neighbor discovery packets separately
            bool foundNeighbor;
            uint16_t size, i = 0;
            neighbor* Neighbor, *neighbor_ptr;
            switch(myMsg->protocol) {
               case PROTOCOL_PING:
               //Configuration packet for neighbor discovery, make sure to send directly back to sender
               //dbg("Project1N", "Received discovery packet, responding to %d\n", myMsg->src);
               makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, myMsg->TTL-1, PROTOCOL_PINGREPLY, myMsg->seq, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));
               pushPack(sendPackage);
               call Sender.send(sendPackage, myMsg->src);
               break;

               case PROTOCOL_PINGREPLY:
               //Received ping reply from NeighborList, time to update their age
               //dbg("Project1N", "Received discovery response from %d\n", myMsg->src);
               //Search for neighor first
               size = call NeighborList.size();
               foundNeighbor = FALSE;
   
               for(i = 0; i < size; i++) {
                  neighbor_ptr = call NeighborList.get(i);
                  if(neighbor_ptr->Node == myMsg->src) {
                     //dbg("Project1N", "Updating node %d in neighbor list\n", myMsg->src);
                     //Found the neighbor, update age
                     neighbor_ptr->Age = 0;
                     foundNeighbor = TRUE;
                     break;
                  }
               }
               //If I found it then exit, otherwise I need to push it into my list
               if(!foundNeighbor) {
                  //dbg("Project1N", "Node %d not found in list so inserting now\n", myMsg->src);
                  Neighbor = call NeighborPool.get();
                  Neighbor->Node = myMsg->src;
                  Neighbor->Age = 0;
                  call NeighborList.pushback(Neighbor);
               }
               break;

               default:
               break;
            }
 
         } else if(TOS_NODE_ID==myMsg->dest){
            dbg("Project1F", "Packet from %d has arrived! Msg: %s\n", myMsg->src, myMsg->payload);
 
            //First thing is to push the incoming packet into our seen/sent list
            //Don't push our command protocols into the list. This breaks sending multiple pings from the same node.
            if(myMsg->protocol != PROTOCOL_CMD) {
               pushPack(*myMsg);    
            }

            switch(myMsg->protocol){
               uint8_t createMsg[PACKET_MAX_PAYLOAD_SIZE];
               uint16_t dest;

               case PROTOCOL_PING:
               //dbg("Project1F", "Sending Ping Reply to %d! \n", myMsg->src);
               makePack(&sendPackage, TOS_NODE_ID, myMsg->src, MAX_TTL,
                     PROTOCOL_PINGREPLY, seqCounter, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));
               seqCounter++;
               //Push the packet we want to send into our seen/sent list
               pushPack(sendPackage);
               call Sender.send(sendPackage, AM_BROADCAST_ADDR);
               break;

               case PROTOCOL_PINGREPLY:
               dbg("Project1F", "Received a Ping Reply from %d!\n", myMsg->src);
               break;

               case PROTOCOL_CMD:
               switch(getCMD((uint8_t *) &myMsg->payload, sizeof(myMsg->payload))){
                  case CMD_PING:
                  memcpy(&createMsg, (myMsg->payload) + CMD_LENGTH+1, sizeof(myMsg->payload) - CMD_LENGTH+1);
                  memcpy(&dest, (myMsg->payload)+ CMD_LENGTH, sizeof(uint8_t));
                  makePack(&sendPackage, TOS_NODE_ID, (dest-48)&(0x00FF),
                        MAX_TTL, PROTOCOL_PING, seqCounter, (uint8_t *)createMsg, sizeof(createMsg)); 
                  seqCounter++;
                  //Push the packet we want to send into our seen/sent list
                  pushPack(sendPackage);
                  call Sender.send(sendPackage, AM_BROADCAST_ADDR);
                  break;
                  
                  case CMD_NEIGHBOR_DUMP:
                  printNeighborList();
                  break;
                  
                  default:
                  break;
               }
               break;
               
               default:
               break;
            }
         } else {
            //Handle packets that do not belong to you
            makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, myMsg->protocol, myMsg->seq, (uint8_t *)myMsg->payload, sizeof(myMsg->payload));
            dbg("Project1F", "Received Message from %d, meant for %d. Rebroadcasting\n", myMsg->src, myMsg->dest);
            pushPack(sendPackage);
            call Sender.send(sendPackage, AM_BROADCAST_ADDR);
         }
         return msg;
      }

      dbg("genDebug", "Unknown Packet Type\n");
      return msg;
   }
   //Searches for a packet in our seen/sent packet list
   bool findPack(pack *Package) {
      uint16_t size = call PacketList.size();
      uint16_t i = 0;
      pack Match;
      for(i = 0; i < size; i++) {
         Match = call PacketList.get(i);
         if(Match.src == Package->src && Match.dest == Package->dest && Match.seq == Package->seq) {
            return TRUE;
         }
      }
      return FALSE;
   }

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }

   void pushPack(pack Package) {
      if(call PacketList.isFull()) {
         call PacketList.popfront();
      }
      call PacketList.pushback(Package);
   }
 
   void discoverNeighborList() {
      pack Package;
      char* message;
      //Age all NeighborList first if list is not empty
      //dbg("Project1N", "Discovery activated: %d checking list for neighbors\n", TOS_NODE_ID);
      if(!call NeighborList.isEmpty()) {
         uint16_t size = call NeighborList.size();
         uint16_t i = 0;
         uint16_t age = 0;
         neighbor* neighbor_ptr;
         neighbor* temp;
         //Age the NeighborList
         for(i = 0; i < size; i++) {
            temp = call NeighborList.get(i);
            temp->Age++;
         }
         //If any are older than 5 neighbor confirmation requests then drop them from our list
         for(i = 0; i < size; i++) {
            temp = call NeighborList.get(i);
            age = temp->Age;
            if(age > 5) {
               neighbor_ptr = call NeighborList.remove(i);
               //dbg("Project1N", "Node %d is older than 5 pings, dropping from list\n", neighbor_ptr->Node);
               call NeighborPool.put(neighbor_ptr);
               i--;
               size--;
            }
         }
      }
      //Ready to ping NeighborList
      message = "womp\n";
      makePack(&Package, TOS_NODE_ID, AM_BROADCAST_ADDR, 2, PROTOCOL_PING, 1, (uint8_t*) message, (uint8_t) sizeof(message));

      pushPack(Package);
      call Sender.send(Package, AM_BROADCAST_ADDR);
   }
 
   void printNeighborList() {
      uint16_t i, size;
      size = call NeighborList.size();
      //Print out NeighborList after updating
      if(size == 0) {
         dbg("Project1N", "No Neighbors found\n");
      } else {
         dbg("Project1N", "Updated Neighbors. Dumping new neighbor list of size %d for Node %d\n", size, TOS_NODE_ID);
         for(i = 0; i < size; i++) {
            neighbor* neighbor_ptr = call NeighborList.get(i);
            dbg("Project1N", "Neighbor: %d, Age: %d\n", neighbor_ptr->Node, neighbor_ptr->Age);
         }
      }
   }     
}