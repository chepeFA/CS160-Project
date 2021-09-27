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
   
   uses interface List<pack> as PacketList;
   uses interface Pool<neighboorDiscovery> as NeighboorPool;
   uses interface List<neighboorDiscovery *> as NeighboorList1;
}

implementation{
   //global variables
   pack sendPackage;
   uint16_t sequenceNumber= 0;
   uint8_t commandID;
   uint16_t srcAdd;

   


   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   void findNeighboors();
   bool seenPackage(pack *package);
   void pushPack(pack package);
   bool isN(uint16_t src);
   void printNeighborList();

   event void Boot.booted(){

      call AMControl.start();
     
        dbg(GENERAL_CHANNEL, "Booted. \n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      call NeighboorTimer.startPeriodic(10000);
        
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void NeighboorTimer.fired() {
  // dbg(GENERAL_CHANNEL,"firing timer \n");
  findNeighboors();
 //printNeighborList();
   
   }


   event void AMControl.stopDone(error_t err){}



   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
   {
      //dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack))
      {
         pack* myMsg=(pack*) payload;
         neighboorDiscovery *nnn;
      

         if(myMsg->TTL==0 || seenPackage(myMsg))
         {
           // dbg(GENERAL_CHANNEL,"Dropping package \n");
         }
         
         else if(myMsg->dest == AM_BROADCAST_ADDR)
         {
          

            bool foundNeighbor;
            uint16_t i,sizeList;
            neighboorDiscovery* neighboor, *temp, *a;
            neighboorDiscovery nd,n;
           // dbg(GENERAL_CHANNEL,"in AM dest \n");

            if(myMsg->protocol == PROTOCOL_PING)
            {
              

               makePack(&sendPackage, TOS_NODE_ID,AM_BROADCAST_ADDR,myMsg->TTL-1, PROTOCOL_PINGREPLY, myMsg->seq, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));
               //sequenceNumber++;
               pushPack(sendPackage);
                call Sender.send(sendPackage, myMsg->src);
                //dbg(FLOODING_CHANNEL," packet from %d, destination %d \n",myMsg->src,myMsg->dest);
             // call Sender.send(sendPackage, AM_BROADCAST_ADDR);
            }


            //hearing back from a neighbor
            else if(myMsg->protocol == PROTOCOL_PINGREPLY)
            {
           
               //dbg(GENERAL_CHANNEL,"Received a package from %d", myMsg->src);
               i=0;
               //new neighbor
             if(!isN(myMsg->src))//!isN(myMsg->src))//)//!isN(myMsg->src))
               {
                  n.node = myMsg->src;
                  n.age=0;
                  call NeighboorList.pushback(n);

                }
         }  

      }
         else if(myMsg->dest == TOS_NODE_ID) //this package is for me
         {

            dbg(FLOODING_CHANNEL," packet from %d.payload: %s \n",myMsg->src,myMsg->payload);

            if(myMsg->protocol != PROTOCOL_CMD)
            {
             pushPack(*myMsg);
            }

            if(myMsg->protocol == PROTOCOL_PING)
            {
               //dbg(NEIGHBOR_CHANNEL," in protocol ping TOS_NODE_ID \n");
              // dbg(NEIGHBOR_CHANNEL,"sending ping to node: %d",myMsg->src);
               makePack(&sendPackage,TOS_NODE_ID,myMsg->src,MAX_TTL,PROTOCOL_PINGREPLY,sequenceNumber,(uint8_t *)myMsg->payload,sizeof(myMsg->payload));
              sequenceNumber++;
               pushPack(sendPackage);
               dbg(FLOODING_CHANNEL," packet from %d, destination %d \n",myMsg->src,myMsg->dest);
              call Sender.send(sendPackage,AM_BROADCAST_ADDR);
              
            }

            else if(myMsg->protocol == PROTOCOL_PINGREPLY)
            {

              dbg(NEIGHBOR_CHANNEL,"Ping is coming from %d \n",myMsg->src);
            }   


            
         }

         else
         {
             
            makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1
            , myMsg->protocol, myMsg->seq, (uint8_t *)myMsg->payload, sizeof(myMsg->payload));
            dbg(FLOODING_CHANNEL,"Rebroadcasting again. Source %d, Destination: %d \n",myMsg->src,myMsg->dest);
            pushPack(sendPackage);
            call Sender.send(sendPackage, AM_BROADCAST_ADDR);
         }
             return msg;

      }


             dbg(GENERAL_CHANNEL, "Unknown Packet Type %d %s \n", len);
             return msg;

}

      
   

   


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
     //dbg(GENERAL_CHANNEL, "PING EVENT \n");
     dbg(FLOODING_CHANNEL,"source: %d \n",TOS_NODE_ID);
     //dbg(FLOODING_CHANNEL,"destination: %d \n",AM_BROADCAST_ADDR);
     dbg(FLOODING_CHANNEL,"destination: %d \n",destination);

     makePack(&sendPackage, TOS_NODE_ID,destination, MAX_TTL, PROTOCOL_PING, sequenceNumber, payload, PACKET_MAX_PAYLOAD_SIZE);
     sequenceNumber++;
     pushPack(sendPackage);
     call Sender.send(sendPackage,AM_BROADCAST_ADDR);//destination);

    //neigboorDiscovery node, neighboor;
    //uint16_t i, sizeList = call NeighboorList.size();
    //for(i=0;i<sizeList;i++)
    //{
      //node = call NeighboorList.get(i);
      //dbg(FLOODING_CHANNEL, "Flooding Packet to : %d \n", node.node );
      //makePack(&sendPackage,);
    //}
   }

   event void CommandHandler.printNeighbors(){

   printNeighborList();
   }

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
   neighboorDiscovery nd,t;
    uint16_t i=0;
    uint16_t sizeList= call NeighboorList.size();
    while(i<sizeList)
    {
      nd = call NeighboorList.get(i);
      nd.age+=1;
      call NeighboorList.remove(i);                    
      call NeighboorList.pushback(nd);
      i++;

    }
    i=0;
    while(i<sizeList)
    {
      t = call NeighboorList.get(i);
      if(t.age>5)
      {
         call NeighboorList.remove(i);
         sizeList--;
         i--;
      }
      i++;
    }
      
   
   //uint16_t i,sizeList,age;


   


   message = "\n";
   makePack(&sendPackage,TOS_NODE_ID,AM_BROADCAST_ADDR,2,PROTOCOL_PING,1,(uint8_t *)message,(uint8_t) sizeof(message));
   pushPack(Package);
   call Sender.send(sendPackage,AM_BROADCAST_ADDR);
   //   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);


   }



   bool seenPackage(pack* package)
   {
      uint16_t sizeList = call PacketList.size();
      uint16_t i =0;
      pack seen;
      while(i<=sizeList)
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

      //if(!call NeighboorList.isEmpty())
      //{
         neighboorDiscovery nx;
         uint16_t i, sizeList = call NeighboorList.size();
         
         i=0;

         while(i<sizeList)
         {
            nx = call NeighboorList.get(i);
            if(nx.node == src)
            {
               nx.age=0;
               return TRUE;
            }
            i++;
         }
      //}
      return FALSE;
   }


   void printNeighborList()
   {
   neighboorDiscovery nd;
   uint16_t i, sizeList;
   sizeList =call NeighboorList.size();// call NeighboorList1.size();
   dbg(NEIGHBOR_CHANNEL,"size list %d:",sizeList);

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
         neighboorDiscovery temp = call NeighboorList.get(i);
         dbg(NEIGHBOR_CHANNEL,"Neighbor: %d \n",temp.node);
         i++;
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