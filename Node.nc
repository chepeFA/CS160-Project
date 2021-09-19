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


//only TTL is decreased hop by hop
typedef nx_struct floodingLayer{
   nx_uint16_t floodSource;
   nx_uint16_t sequenceNumber;
   nx_uint16_t TTL;

}floodingLayer;


//changes hop by hop
typedef nx_struct linkLayer{
   nx_uint16_t sourceAddress;
   nx_uint16_t destinationAdress;
  

}linkLayer;
//application payload: payload is in the packgare



typedef nx_struct neighboor{
   nx_uint16_t node;
   nx_uint16_t age;
}neighboor;


typedef nx_struct nD{  //nd = neighboorDiscovery
    
    nx_uint8_t typeMessage; //request or reply;
    nx_uint16_t sequenceNumber;
    nx_uint16_t sourceAddress;
    nx_uint16_t destinationAddress;
    nx_uint16_t node;
    nx_uint16_t age;
}nD;



module Node{
   uses interface Boot;
   uses interface Random as RandomTimer; 
   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   uses interface Timer<TMilli> as NeighboorTimer;
   uses interface List<pack> as PacketList;
   uses interface List<nD *> as NeighboorList;
   uses interface Pool<nD> as NeighboorPool;




   
}

implementation{
   pack sendPackage;
   uint16_t seqNumber=0; //store largest sequence number fromm any nodes flood
   uint16_t totalNodes=0;
   uint16_t start;
    
   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   int seenPackage(pack *package);
   void printNeighboorList();
   void neighboorDiscovery();
   void pushPack(pack Package);
   bool isNeighboor(uint16_t node);



   event void Boot.booted(){

       totalNodes++; //to keep track of the numbers of nodes in the topology

     
      call AMControl.start();
    

      dbg(GENERAL_CHANNEL, "Booted\n");
      
       //start = call RandomTimer.rand16();

      //call NeighboorTimer.startPeriodicAt(0,start);

      //Fire timers
      //dbg(GENERAL_CHANNEL,"Neigboor Timer started at %d \t being shot every: %d \t",0,start);

   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
         call NeighboorTimer.startPeriodic(1000);
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      neighboor ne;
      uint16_t seen;
      uint16_t message[PACKET_MAX_PAYLOAD_SIZE];
      uint16_t dest;
      //totalNodes++;

     // dbg(GENERAL_CHANNEL, "Packet Received\n");
      //dbg(GENERAL_CHANNEL, "Total number of nodes in this topology %d\n",totalNodes);
     


      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;

          seen = seenPackage(myMsg);
         dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);


         //check if we've seen this package before
         if(myMsg->TTL==0 || seen==1) //we've seen it before
         {
            //do not do anything yet
         }
         else if(myMsg->dest==TOS_NODE_ID) //receiving node needs to reply back
         {

           // if(myMsg->protocol !=PROTOCOL_CMD)
            //{
              // pushPack(*myMsg);
           // }
           uint8_t createMsg[PACKET_MAX_PAYLOAD_SIZE];
         

            if(myMsg->protocol == PROTOCOL_PING) //protocol ping
            {
               // dbg(GENERAL_CHANNEL, "Protocol ping reply was activated");
               makePack(&sendPackage,TOS_NODE_ID,myMsg->src,MAX_TTL,PROTOCOL_PINGREPLY,seqNumber,(uint8_t *) myMsg->payload,sizeof(myMsg->payload) );
               seqNumber++;
               pushPack(sendPackage);
               call Sender.send(sendPackage,AM_BROADCAST_ADDR);
               goto b;
            }

            if(myMsg->protocol==PROTOCOL_PINGREPLY)//protocol pingReply
            {
               dbg(FLOODING_CHANNEL, "Received the ping reply from %d\n", myMsg->src);
                    //break; 
                    goto b;
            }

            b:


         }
         else if(myMsg->dest==AM_BROADCAST_ADDR)
         {
           bool foundNeighboor;
          
            neighboor* temp;
            uint16_t i; 
            uint16_t sizeList = call NeighboorList.size();
         /*

           
            
          
            if(myMsg->protocol==PROTOCOL_PING)//protocol ping
            {
                  makePack(&sendPackage,TOS_NODE_ID,AM_BROADCAST_ADDR,myMsg->TTL-1,PROTOCOL_PINGREPLY,myMsg->seq,(uint8_t *)myMsg->payload,sizeof(myMsg->payload));
                  pushPack(sendPackage);
                  call Sender.send(sendPackage,myMsg->src);
                  goto a;
            }
            if(myMsg->protocol==PROTOCOL_PINGREPLY)//protocol ping reply
            {
               
               if(!isNeighboor(myMsg->src))
               {
                  ne->node=myMsg->src;
                  ne->age=0;
                  call NeighboorList.pushback(ne);
                  
                  
               }
               //goto a;
               
               /*
                foundNeighboor =FALSE;
                i=0;
                while(i<sizeList)
                {
                 temp = call NeighboorList.get(i);
                 if(temp.node==myMsg->src)
                 {
                  temp.age=0;
                  foundNeighboor=TRUE;
                  goto a;
                  i++;
                 }
                }

                if(!foundNeighboor)
                {

                  ne.node = myMsg->src;
                  ne.age=0;
                  call NeighboorList.pushback(ne);
                  goto a;



                }

            }
           
            //a:
            */
           // a:
            
            /*

            //*************************************************************
            // if receive a package. you are my neighboor. & I need to see how you are communicatiiong with me
            //bool foundNeighboor;
            nD* nNeighboor; 
            nD* nNeighboor_ptr;
            //uint16_t sizeList = call  NeighboorList.size();
            if(myMsg->protocol == PROTOCOL_PING)
            {
                        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, myMsg->TTL-1, PROTOCOL_PINGREPLY, myMsg->seq, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));
                        pushPack(sendPackage);
                        call Sender.send(sendPackage,myMsg ->src);
            }
            if(myMsg->protocol==PROTOCOL_PINGREPLY)
            {
              foundNeighboor = FALSE;
              i=0;
              while(i<sizeList)
              {
                nNeighboor_ptr = call NeighboorList.get(i);
                if(nNeighboor_ptr->node == myMsg->src)
                {
                  nNeighboor_ptr->age=0;
                  foundNeighboor=TRUE;
                  break;
                }

              }

              if(!foundNeighboor)
              {
                nNeighboor = call NeighboorPool.get();
                nNeighboor->node= myMsg->src;
                nNeighboor->age=0;
                call NeighboorList.pushback(nNeighboor);


              }
            }
            */

         }
         else
         {
         makePack(&sendPackage,myMsg->src,myMsg->dest,myMsg->TTL-1,myMsg->protocol,myMsg->seq,(uint8_t *)myMsg->payload,sizeof(myMsg->payload));
         dbg(GENERAL_CHANNEL,"Message from %d. Message is for %d",myMsg->src,myMsg->dest);
         pushPack(sendPackage);
         call Sender.send(sendPackage, AM_BROADCAST_ADDR);
         }


         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);

      return msg;



   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
   //totalNodes++; //to keep track of the numbers of nodes in the topology
     
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, seqNumber, payload, PACKET_MAX_PAYLOAD_SIZE);
      seqNumber++;
      pushPack(sendPackage);
      //call Sender.send(sendPackage, destination);
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

   void pushPack(pack Package)
   {
    if(call PacketList.isFull())
    {

     call PacketList.popfront();
    }
     call PacketList.pushback(Package);
   }


   int seenPackage(pack* package)
   {
      pack temp;
      uint16_t i;

      i=0;

      while(i < call PacketList.size()) //transerve all packages to see if we have seen one 
      {
         temp = call PacketList.get(i);
         if(temp.src == package->src && temp.seq == package->seq && temp.dest == package->dest)
         {
            return 1; //we have seen the package before
         }

      i++;
      }

      return 2;// we have not seen the package
   }

   void neighboorDiscovery()
   {
   char* message;
   pack Package;
   
   
 // dbg(NEIGHBOR_CHANNEL, "in neighboor discovery\n");
 if(!call NeighboorList.isEmpty())
 {
  uint16_t sizeList = call NeighboorList.size();
 uint16_t i=0;
   uint16_t age=0;
   nD* n_ptr;
   nD* temp;

 //uint16_t sizeList = call NeighboorList.size();


  while(i<sizeList)
  {

    temp = call NeighboorList.get(i);
    temp->age++;
      //n = call NeighboorList.get(i);
      //n.age++;
     // call NeighboorList.remove(i);
      //call NeighboorList.pushback(n);
      i++;
  }
  i=0;
  do
  {
      temp = call NeighboorList.get(i);
      age= temp->age;
      if(age>5)
      {
         temp = call NeighboorList.remove(i);
         call NeighboorPool.put(temp);
         sizeList--;
         i--;

      }
      i++;
  }while(i<sizeList);

  }

  message = "tes";
  makePack(&Package, TOS_NODE_ID,AM_BROADCAST_ADDR,2,PROTOCOL_PING,1,(uint8_t *)message,(uint8_t)sizeof(message));
  pushPack(Package);
  call Sender.send(Package, AM_BROADCAST_ADDR);






   }


   bool isNeighboor(uint16_t node)
   {
   uint16_t i;
 
   neighboor n;

      if(!call NeighboorList.isEmpty())
      {
        uint16_t sizeList = call NeighboorList.size();
      i=0;
         do{

            &(n) = call NeighboorList.get(i);
            if(n.node==node)
            {
               n.age=0;
               return TRUE;
            }
         }while(i<sizeList);
      }
      return FALSE;
   }
   

   void printNeighboors()
   {
  neighboor temp;
   uint16_t i, sizeList;
   sizeList = call NeighboorList.size();
  
   if(sizeList==0)
   {
    dbg(GENERAL_CHANNEL,"No neighboors found\n");
   }
   else
   {
         dbg(NEIGHBOR_CHANNEL,"Below are the neighboors List of size %d for Node %d",sizeList,TOS_NODE_ID);
         i=0;
         while(i<sizeList)
         {
           // temp = call NeighboorList.get(i);
           // dbg(NEIGHBOR_CHANNEL,"Neigboor: %d ", temp.node);
           nD* neighboor_ptr = call NeighboorList.get(i);
           //neighboor_ptr->age++;
           //NeighboorList.pushback(neighboor_ptr);
          dbg(GENERAL_CHANNEL,"Neighboor %d, Age: %d", neighboor_ptr->node,neighboor_ptr->age);
         }
   }
  
   }

   
}
