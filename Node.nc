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

typedef nx_struct neighboorDiscovery{ //first two fields are for nd header
nx_uint16_t petition;
nx_uint16_t sequenceNumber;
nx_uint16_t sourceAddress;  //last two fields are for link layer headers
nx_uint16_t destinationAddress;
nx_uint16_t node;
nx_uint16_t age;
}neighboorDiscovery;


module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;
   uses interface SimpleSend as Sender;
   uses interface CommandHandler;

   uses interface Timer<TMilli> as NeighboorTimer;
   uses interface Random as RandomTimer;
   uses interface List<neighboorDiscovery> as NeighboorList;
   uses interface List<neighboorDiscovery *> as NeighboorList1;
   uses interface List<pack> as PacketList;
   uses interface Pool<neighboorDiscovery> as NeighboorPool;
}

implementation{
   //global variables
   pack sendPackage;
   uint16_t sequenceNumber= 0;
   uint8_t commandID;
   uint16_t LSTable[20][20];


   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   void findNeighboors();
   bool seenPackage(pack* package);
   void pushPack(pack package);
   bool isN(uint16_t src);
   void printNeighborList();

   event void Boot.booted(){

      call AMControl.start();
      call NeighboorTimer.startPeriodic(10000);
        dbg(GENERAL_CHANNEL, "Booted. \n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
        
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void NeighboorTimer.fired() {
  // dbg(GENERAL_CHANNEL,"firing timer \n");
  findNeighboors();
  printNeighborList();
   
   }


   event void AMControl.stopDone(error_t err){}



   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      //dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
        // dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
        //return msg;

         if(myMsg->TTL==0 || seenPackage(myMsg))
         {
           // dbg(GENERAL_CHANNEL,"Dropping package \n");
         }
         
         if(myMsg->dest == AM_BROADCAST_ADDR)
         {
            bool foundNeighbor;
            uint16_t i,sizeList;
            neighboorDiscovery* neighboor;
            neighboorDiscovery* temp;
           

            if(myMsg->protocol == PROTOCOL_PING)
            {
               dbg(NEIGHBOR_CHANNEL," protocol ping AM \n");

               makePack(&sendPackage, TOS_NODE_ID,AM_BROADCAST_ADDR,myMsg->TTL-1, PROTOCOL_PINGREPLY, myMsg->seq, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));
               //sequenceNumber++;
               pushPack(sendPackage);
               call Sender.send(sendPackage, myMsg->src);
               //call Sender.send(sendPackage, AM_BROADCAST_ADDR);
            }

            else if(myMsg->protocol == PROTOCOL_PINGREPLY)
            {

            neighboorDiscovery* nd;
            /*
                 //dbg(NEIGHBOR_CHANNEL," protocol ping REPLY AM \n");
               sizeList = call NeighboorList1.size();
               foundNeighbor = FALSE;
               i=0;
               while(i<sizeList)
               {
                  neighboor = call NeighboorList1.get(i);
                  if(neighboor->node==myMsg->src)
                  {
                     neighboor->age=0;
                     foundNeighbor =TRUE;
                     break;
                  }

               }

               //new neighbor
               if(!foundNeighbor)//!isN(myMsg->src))//)//!isN(myMsg->src))
               {

                  //neighboor = call NeighboorList.get();
                  dbg(NEIGHBOR_CHANNEL," in !foundNeighboor \n");
                  temp = call NeighboorPool.get();
                  temp->node = myMsg->src;
                  temp->age=0;
                  call NeighboorList1.pushback(temp);
                  //call NeighboorPool.put(temp);
                  //nd.node= myMsg->src;
                  //nd.age=0;
                  //call NeighboorList.pushback(nd);


               }

               */

               if(!isN(myMsg->src))
               {
                  nd->node = myMsg->src;
                  nd->age=0;
                  call NeighboorList1.pushback(nd);
               }
            }
         }  
         else if(myMsg->dest == TOS_NODE_ID) //this package is for me
         {
            dbg(NEIGHBOR_CHANNEL," packet from %d. Content: %s",myMsg->src,myMsg->payload);
            if(myMsg->protocol != PROTOCOL_CMD)
            {
               pushPack(*myMsg);
            }

            if(myMsg->protocol == PROTOCOL_PING)
            {
               dbg(NEIGHBOR_CHANNEL," in protocol ping TOS_NODE_ID \n");

               makePack(&sendPackage,TOS_NODE_ID,myMsg->src,MAX_TTL,PROTOCOL_PINGREPLY,sequenceNumber,(uint8_t *)myMsg->payload,sizeof(myMsg->payload));
              sequenceNumber++;
               pushPack(sendPackage);
              call Sender.send(sendPackage,AM_BROADCAST_ADDR);
            }

            else if(myMsg->protocol == PROTOCOL_PINGREPLY)
            {

               dbg(NEIGHBOR_CHANNEL,"Ping is coming from %d",myMsg->src);
            }          
         }

         else
         {
      
            makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, myMsg->protocol, myMsg->seq, (uint8_t *)myMsg->payload, sizeof(myMsg->payload));
           
            pushPack(sendPackage);
            call Sender.send(sendPackage, AM_BROADCAST_ADDR);
         }
             return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_PING, sequenceNumber, payload, PACKET_MAX_PAYLOAD_SIZE);
      sequenceNumber++;
      pushPack(sendPackage);
    //  call Sender.send(sendPackage, AM_BROADCAST_ADDR);//destination);
   }

   event void CommandHandler.printNeighbors(){}

   event void CommandHandler.printRouteTable(){}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}


   void findNeighboors()
   {

   pack Package;
   char* message;
   
   //uint16_t i,sizeList,age;


   if(!call NeighboorList.isEmpty())
   {
      uint16_t sizeList= call NeighboorList1.size();
      uint16_t i=0;
      uint16_t age=0;
      neighboorDiscovery* temp;
      neighboorDiscovery* neighboorPointer;

      while(i<sizeList)
      {
         temp = call NeighboorList1.get(i);
         temp->age=temp->age+1;
         //call NeighboorList1.remove(i);
         //call NeighboorList1.pushback(temp);
         i++;
      }

      i=0;
      do{

         temp = call NeighboorList1.get(i);
         age = temp->age;
         if(age>5)
         {
            neighboorPointer = call NeighboorList1.remove(i);
           // call NeighboorPool.put(neighboorPointer);
            i--;
            sizeList--;
         }
         i++;
      }while(i<sizeList);
   }


   message = "ping \n";
   makePack(&sendPackage,TOS_NODE_ID,AM_BROADCAST_ADDR,2,PROTOCOL_PING,1,(uint8_t *)message,(uint8_t) sizeof(message));
   pushPack(sendPackage);
   call Sender.send(sendPackage,AM_BROADCAST_ADDR);
   //   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);


   }



   bool seenPackage(pack* package)
   {
      uint16_t sizeList = call PacketList.size();
      uint16_t i =0;
      pack seen;
      while(i<sizeList)
      {
         seen = call PacketList.get(i);
         if(seen.src == package->src && seen.dest == package->dest && seen.seq==package->seq)
         {
            return TRUE;
         }
         i++;
      }
      return FALSE;
   }

   void pushPack(pack Package)
   {
    
      call PacketList.pushback(Package);
   }

   bool isN(uint16_t src)
   {
      if(!call NeighboorList1.isEmpty())
      {
         uint16_t i, sizeList = call NeighboorList1.size();
         neighboorDiscovery nd;
         i=0;

         while(i<sizeList)
         {
            nd = call NeighboorList.get(i);
            if(nd.node ==src)
            {
               nd.age=0;
               return TRUE;
            }
         }
      }
      return FALSE;
   }


   void printNeighborList()
   {
   uint16_t i, sizeList;
   sizeList = call NeighboorList1.size();
   if(sizeList==0)//call NeighboorList1.isEmpty)
   {
      dbg(NEIGHBOR_CHANNEL,"No neighbors \n");
   }
   else
   {
      dbg(NEIGHBOR_CHANNEL,"Neighbors for node %d:  \n",TOS_NODE_ID);
      i=0;
      while(i<sizeList)
      {
         neighboorDiscovery* temp = call NeighboorList1.get(i);
         dbg(NEIGHBOR_CHANNEL,"Neighbor: %d, Age: %d",temp->node,temp->age);
      }
   }
   }

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}