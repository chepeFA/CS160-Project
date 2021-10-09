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

typedef nx_struct tableLS{
  nx_uint16_t destination;
  nx_uint16_t nextHop;
  nx_uint16_t cost;

}tableLS;



module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;
   uses interface SimpleSend as Sender;
   uses interface CommandHandler;

   //PROJECT 1
   uses interface Timer<TMilli> as NeighboorTimer;
   uses interface Random as RandomTimer;
   uses interface List<neighboorDiscovery> as NeighboorList;
   uses interface List<pack> as PacketList;
   uses interface Pool<neighboorDiscovery> as NeighboorPool;
   uses interface List<neighboorDiscovery *> as NeighboorList1;


   //PROJECT 2
   uses interface Hashmap<tableLS> as RoutingTable;//forwarding table for each node
   uses interface Hashmap<pack> as PacketCache;// to implment cache
   uses interface Timer<TMilli> as RoutingTimer;
   uses interface List<pack> as LSAPacketCache;
}

implementation{
   //global variables
   pack sendPackage;
   uint16_t sequenceNumber= 0;
   uint8_t commandID;
   uint16_t srcAdd;
   uint16_t itlAdd;
   uint16_t fnlAdd;
   uint16_t cost=0; //number of hops
   uint16_t temp;

   //Project 2
    tableLS routingTable[255]={0}; //initialize all structs fields to zero.
    uint16_t seqNumberLSA=0;
   


   // Prototypes Project 1
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   void findNeighboors();
   bool seenPackage(pack *package);
   void pushPack(pack package);
   bool isN(uint16_t src);
   void printNeighborList();

   // Prototypes Project 2
   int seenPacketLSA(int seen);
   void dijkstra();
   void forwarding(pack* Package);
   void printLSTable();
   void printRoutingTable();
   void localroute();
   void Route_flood();
   void checkdest(tableLS* tmptable);
   bool checkMin(tableLS* tmptable);








   event void Boot.booted(){

      call AMControl.start();
     
        dbg(GENERAL_CHANNEL, "Booted. \n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
         //start neighbor discovery and routing timer as soon as radio is on
      call NeighboorTimer.startPeriodic(10000);

      call RoutingTimer.startPeriodic(30000);
        
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

   event void RoutingTimer.fired()
   {
    void sendLSP();
   }



   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
   {
   
      //dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack))
      {
         pack* myMsg=(pack*) payload;
         neighboorDiscovery *nnn;
      

         if(myMsg->TTL==0 || seenPackage(myMsg))
         {
          
         }
         
         else if(myMsg->dest == AM_BROADCAST_ADDR)
         {
          

            bool foundNeighbor;
            uint16_t i,sizeList;
            neighboorDiscovery* neighboor, *temp, *a;
            neighboorDiscovery nd,n;
           

            if(myMsg->protocol == PROTOCOL_PING)
            {
              
              //cost++;
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

           // cost++;
            dbg(FLOODING_CHANNEL," packet from %d.payload: %s \n",myMsg->src,myMsg->payload);
            
           // temp=cost;

            if(myMsg->protocol != PROTOCOL_CMD)
            {
             pushPack(*myMsg);
            }

            if(myMsg->protocol == PROTOCOL_PING)
            {

             // uint32_t nexxxtHop = call RoutingTable.get(myMsg->src);
            
               //dbg(NEIGHBOR_CHANNEL," in protocol ping TOS_NODE_ID \n");
              // dbg(NEIGHBOR_CHANNEL,"sending ping to node: %d",myMsg->src);
               makePack(&sendPackage,TOS_NODE_ID,myMsg->src,MAX_TTL,PROTOCOL_PINGREPLY,sequenceNumber,(uint8_t *)myMsg->payload,sizeof(myMsg->payload));
              sequenceNumber++;
               pushPack(sendPackage);
               //dbg(FLOODING_CHANNEL," packet from %d, destination %d \n",myMsg->src,myMsg->dest);
              //working on 10.08 call Sender.send(sendPackage,AM_BROADCAST_ADDR);


              
              if(call RoutingTable.get(myMsg->src))
              {
                  dbg(ROUTING_CHANNEL,"Sending package to next hop %d n",call RoutingTable.get(myMsg->src));
                  call Sender.send(sendPackage,call RoutingTable.get(myMsg->src));
              }
              
            }

            else if(myMsg->protocol == PROTOCOL_PINGREPLY)
            {

              dbg(NEIGHBOR_CHANNEL,"Ping is coming from %d \n",myMsg->src);
            }   


            
         }

         else //Broadcasting
         {
            //cost++;
            makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1
            , myMsg->protocol, myMsg->seq, (uint8_t *)myMsg->payload, sizeof(myMsg->payload));
            //dbg(FLOODING_CHANNEL,"Rebroadcasting again. We are in node:  %d, going to,  Destination: %d \n",TOS_NODE_ID,myMsg->dest);
            pushPack(sendPackage);
            call Sender.send(sendPackage, AM_BROADCAST_ADDR);
         }
             return msg;

      }


             dbg(GENERAL_CHANNEL, "Unknown Packet Type %d %s \n", len);
             return msg;

}

      
   

   


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
    
  
     dbg(FLOODING_CHANNEL,"source: %d \n",TOS_NODE_ID);
     dbg(FLOODING_CHANNEL,"destination: %d \n",destination);
     itlAdd = TOS_NODE_ID;
     fnlAdd= destination;
     
     
     makePack(&sendPackage, TOS_NODE_ID,destination, MAX_TTL, PROTOCOL_PING, sequenceNumber, payload, PACKET_MAX_PAYLOAD_SIZE);
     sequenceNumber++;
     pushPack(sendPackage);//send package to our cache

     call Sender.send(sendPackage,AM_BROADCAST_ADDR);//destination);
    

   }

   event void CommandHandler.printNeighbors(){

   printNeighborList();
   // dbg(GENERAL_CHANNEL,"cost is: %d \n",cost);

   }

   event void CommandHandler.printRouteTable(){
  // printRoutingTable();
   }

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
   makePack(&Package,TOS_NODE_ID,AM_BROADCAST_ADDR,2,PROTOCOL_PING,1,(uint8_t *)message,(uint8_t) sizeof(message));
   pushPack(Package);
   call Sender.send(Package,AM_BROADCAST_ADDR);
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

   void PackCacheHash(pack Package,int id)
   {
    if(seenPacketLSA==0 && Package.src==TOS_NODE_ID)
    {
      call PacketCache.insert(id,sendPackage);
    }
    else if(seenPacketLSA==1 && Package.src==TOS_NODE_ID )
    {
      call PacketCache.remove(id);
      call PacketCache.insert(id,sendPackage);

    }
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


   //PROJECT_2 FUNCTIONS

   int seenPacketLSA(int id)
   {
    if(!call PacketCache.contains(id)) //is not in the cache
    {
      return 0;
    }
    else //it is in the cache
    {
       return 1;
    }
   
   }

   void printRoutingTable()
   {
      uint16_t i=0;
      tableLS routingTable;

      dbg(ROUTING_CHANNEL,"Routing Table: \n");
      dbg(ROUTING_CHANNEL,"Dest \t, Next Hop: \t, Cost \n");
      while(i<19)
      {
        routingTable = call RoutingTable.get(i);
        if(routingTable.cost!=0)
        {
        dbg(ROUTING_CHANNEL,"%d\t  %d\t,  %d\n",routingTable.destination,routingTable.nextHop,routingTable.cost);
        i++;
        }
      }
   }


   void sendLSP()
   {
    tableLS potentialRoute[1];
    uint16_t* key = call RoutingTable.getKeys();
    uint16_t i=0;

    for(i=0;key[i]!=0;i++)
    {
      potentialRoute[0]=call RoutingTable.get(key[i]);
      makePack(&sendPackage,TOS_NODE_ID,AM_BROADCAST_ADDR,0,PROTOCOL_LINKEDLIST,0,(uint8_t*)potentialRoute,sizeof(tableLS)*1);
      call Sender.send(sendPackage,AM_BROADCAST_ADDR);
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