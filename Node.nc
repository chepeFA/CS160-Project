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
  nx_uint8_t destination;
  nx_uint8_t nextHop;
  nx_uint8_t cost;
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
   uses interface Hashmap<uint16_t> as RoutingTable1;
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
   void sendLSP();
   int seenPacketLSA(int seen);
   void computeDijkstra();
   void forwarding(pack* Package);
   void printLSTable();
   void printRoutingTable();
   void localroute();
   void Route_flood();
   void checkdest(tableLS* tempTable);
   bool checkMin(tableLS* tempTable);
   void insertTable(tableLS* tempTable);
   void nodeNeighborCost();
   void IPModule(pack* LSPacket);








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
    sendLSP();
   }



   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
   {
   tableLS route[1];
   
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
            neighboorDiscovery* neighboor, *ttemp, *a;
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
             //IPModule(myMsg);
            }


            //hearing back from a neighbor
            else if(myMsg->protocol == PROTOCOL_PINGREPLY)
            {
           
               //dbg(GENERAL_CHANNEL,"Received a package from %d", myMsg->src);
               i=0;
               //new neighbor
             if(!isN(myMsg->src))//!isN(myMsg->src))//)//!isN(myMsg->src))
               {
                  //
                  nodeNeighborCost();
                  n.node = myMsg->src;
                  n.age=0;
                  call NeighboorList.pushback(n);


                  //pj2 
                  nodeNeighborCost();

                }
         }

         else if(myMsg->protocol == PROTOCOL_LINKSTATE)
         {
          dbg(ROUTING_CHANNEL,"in protocol link state \n");
            memcpy(route,myMsg->payload,sizeof(route)*1);
            route[0].nextHop = myMsg->src;
            checkdest(route);
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


              
              if(call RoutingTable.contains(myMsg->src))
              {
                 tableLS a;
                 a = call RoutingTable.get(myMsg->src);
                  dbg(ROUTING_CHANNEL,"Sending package to next hop %d n",call RoutingTable.get(myMsg->src));
                 //call Sender.send(sendPackage);//destination is one 
              }
               else
                dbg(ROUTING_CHANNEL, "Path not found, cancelling reply\n");
              
            }

            else if(myMsg->protocol == PROTOCOL_PINGREPLY)
            {

              dbg(NEIGHBOR_CHANNEL,"Ping is coming from %d \n",myMsg->src);
            }   


            
         }

         else //Broadcasting
         {
         tableLS b;
         b = call RoutingTable.get(myMsg->src);
            //cost++;
            makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1
            , myMsg->protocol, myMsg->seq, (uint8_t *)myMsg->payload, sizeof(myMsg->payload)); 
            //dbg(FLOODING_CHANNEL,"Rebroadcasting again. We are in node:  %d, going to,  Destination: %d \n",TOS_NODE_ID,myMsg->dest);
            pushPack(sendPackage);

           //working from pj 1 
           //call Sender.send(sendPackage, AM_BROADCAST_ADDR);
          
           if(call RoutingTable.contains(myMsg->dest))
           {
            call Sender.send(sendPackage,b.nextHop);
           }
           else
           {
           dbg(ROUTING_CHANNEL,"Route not found \n");
           }
         }
             return msg;

      }


             dbg(GENERAL_CHANNEL, "Unknown Packet Type %d %s \n", len);
             return msg;

}

      
   

   


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
    
      tableLS route;
    //  route = call RoutingTable.get(destination);
     dbg(FLOODING_CHANNEL,"source: %d \n",TOS_NODE_ID);
     dbg(FLOODING_CHANNEL,"destination: %d \n",destination);
     itlAdd = TOS_NODE_ID;
     fnlAdd= destination;

     
     
     makePack(&sendPackage, TOS_NODE_ID,destination, MAX_TTL, PROTOCOL_PING, sequenceNumber, payload, PACKET_MAX_PAYLOAD_SIZE);
     sequenceNumber++;
     pushPack(sendPackage);//send package to the cache
     dbg(ROUTING_CHANNEL,"after push packet\n");
     
      route = call RoutingTable.get(routingTable[0].destination);
   if(call RoutingTable.get(routingTable[0].destination))
   {
   dbg(ROUTING_CHANNEL,"Sending to next hop");
   call Sender.send(sendPackage,call RoutingTable.get(routingTable[0].destination));
   }
   else
   {
   dbg(ROUTING_CHANNEL,"Route to destination not found...\n");
   }


     //Project 1 sender all Sender.send(sendPackage,AM_BROADCAST_ADDR);//destination);
    // if(call RoutingTable.contains(destination))
     //{
          
     //route = call RoutingTable.get(destination);
     //dbg(ROUTING_CHANNEL,"Sending to next hop %d \n",call RoutingTable.get(destination));
   //  call Sender.send(sendPackage,destination);
     //}

     //else{


      //dbg(ROUTING_CHANNEL, "Route to destination not found...\n");
        //}

        /*
    if(call RoutingTable.contains(destination))
    {
      route = call RoutingTable.get(destination);
      dbg(ROUTING_CHANNEL,"here \n");
      
      if(route.cost!=1)
      {
        dbg(ROUTING_CHANNEL,"Routing Packet - src: %d, dest: %d, seq: %d, next hop: %d, cost:%d \n",TOS_NODE_ID,destination,MAX_TTL,route.nextHop,route.cost);
         makePack(&sendPackage, TOS_NODE_ID, destination, 3,PROTOCOL_PING, sequenceNumber, (uint8_t*) payload, sizeof(payload));
         call Sender.send(sendPackage,route.nextHop); //will send to next node
      }
      else
      {
        dbg(ROUTING_CHANNEL,"Routing Packet - src: %d, dest: %d, seq: %d, next hop: %d, cost:%d, protocol %d \n",TOS_NODE_ID,destination,sequenceNumber,route.nextHop,route.cost,TOS_NODE_ID, destination, 3, PROTOCOL_PING, sequenceNumber, (uint8_t*) payload, sizeof( payload));
        call Sender.send(sendPackage,destination); //will send to its dest
      }
    }

    else
    {
         tableLS route;
route = call RoutingTable.get(destination);
    dbg(ROUTING_CHANNEL,"here 2\n");
 
if(route.cost==1){

dbg(ROUTING_CHANNEL,"Routing Packet - src: %d, dest: %d, seq: %d, next hop: %d, cost: \n",TOS_NODE_ID,destination,sequenceNumber,route.nextHop);
makePack(&sendPackage, TOS_NODE_ID, destination, 3, PROTOCOL_PING, sequenceNumber, (uint8_t*) payload, sizeof(payload));
call Sender.send(sendPackage,route.nextHop);
    }

   }
   */
 
  

   }



   event void CommandHandler.printNeighbors(){

   printNeighborList();
   // dbg(GENERAL_CHANNEL,"cost is: %d \n",cost);

   }

   event void CommandHandler.printRouteTable(){
  //printRoutingTable();
   }

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   //PROJECT 1 functions---------------------------------------------------


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
    else if(seenPacketLSA ==1 && Package.src==TOS_NODE_ID )
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
         neighboorDiscovery temP = call NeighboorList.get(i);

         dbg(NEIGHBOR_CHANNEL,"Neighbor: %d \n",temP.node);
         i++;
      }
   }
   
  

   }


   //PROJECT_2 FUNCTIONS----------------------------------------

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
      tableLS rT;

      dbg(ROUTING_CHANNEL,"Routing Table: \n");
      dbg(ROUTING_CHANNEL,"Dest \t, Next Hop: \t, Cost \n");
      while(i<20)
      {
        rT = call RoutingTable.get(i);
        if(rT.cost!=0)
        {
        dbg(ROUTING_CHANNEL,"%d\t  %d\t,  %d\n",rT.destination,rT.nextHop,rT.cost);
        i++;
        }
      }
   }

   void nodeNeighborCost()// populate routing table w neighbor costs
   {
      neighboorDiscovery nodeTemp;
      uint16_t neighborListSize = call NeighboorList.size();
      uint16_t i=0;
      while(i<neighborListSize)
      {

        nodeTemp=  call NeighboorList.get(i);
        if(nodeTemp.node !=0 && ! call RoutingTable.contains(nodeTemp.node))
        {
           // 
            routingTable[i].destination = nodeTemp.node;
            routingTable[i].nextHop = TOS_NODE_ID;
            routingTable[i].cost = 1;
            call RoutingTable.insert(routingTable[i].destination,routingTable[i]);

        }

        i++;
      }
      sendLSP();
   }


   void sendLSP() //send advs of lsa packets
   {

    tableLS potentialRoute[1];
    uint32_t* key = call RoutingTable.getKeys();
    
    uint16_t i=0;


    for(i=0;key[i]!=0;i++)
    {
      potentialRoute[0]=call RoutingTable.get(key[i]);
      makePack(&sendPackage,TOS_NODE_ID,AM_BROADCAST_ADDR,0,PROTOCOL_LINKSTATE,sequenceNumber,(uint8_t*)potentialRoute,sizeof(tableLS)*1);
      call Sender.send(sendPackage,AM_BROADCAST_ADDR);
      //dbg(ROUTING_CHANNEL,"In sendLSP \n");
    }
   }

   void IPModule(pack* LSPacket)
   {
   tableLS route;
   bool exists = call RoutingTable.contains(LSPacket->dest);
      if(exists)
      {
        route = call RoutingTable.get(LSPacket->dest);
        if(route.cost!=1)
        {
          dbg(ROUTING_CHANNEL,"Routing Packet: source: %d, destination: %d, sequence: %d, Next Hop: %d, cost:%d \n",LSPacket->src,LSPacket->dest,LSPacket->seq,route.nextHop,route.cost);


          makePack(&sendPackage,LSPacket->src,LSPacket->dest,3,LSPacket->protocol,LSPacket->seq,(uint8_t*)LSPacket->payload,sizeof(LSPacket->payload));
          call Sender.send(sendPackage,route.nextHop);

        }
        else
        {
        dbg(ROUTING_CHANNEL,"sending to other route");
         makePack(&sendPackage,LSPacket->src,LSPacket->dest,3,LSPacket->protocol,LSPacket->seq,(uint8_t*)LSPacket->payload,sizeof(LSPacket->payload));
          call Sender.send(sendPackage,LSPacket->dest);

        }
      }
      else
      {
      route = call RoutingTable.get(LSPacket->dest);
      if(route.cost==1)
      {
         dbg(ROUTING_CHANNEL,"Routing Packet: source: %d, destination: %d, sequence: %d, Next Hop: %d, cost:%d \n",LSPacket->src,LSPacket->dest,LSPacket->seq,route.nextHop,route.cost);


          makePack(&sendPackage,LSPacket->src,LSPacket->dest,3,PROTOCOL_PING,LSPacket->seq,(uint8_t*)LSPacket->payload,sizeof(LSPacket->payload));
          call Sender.send(sendPackage,route.nextHop);
      }
      }
   }

   void checkdest(tableLS* tempTable)
   {
      uint16_t i=0,j=0;
      if(checkMin(tempTable))
      {
        if(!call RoutingTable.contains(tempTable[i].destination) && tempTable[i].destination!= TOS_NODE_ID)
        {
          insertTable(tempTable);
        }
      }
   }

   bool checkMin(tableLS* tempTable)
   {
      tableLS route;
      route = call RoutingTable.get(tempTable[0].destination);
      if(route.cost!=0 && route.cost> tempTable[0].cost)
      {
        return TRUE;
      }
      if(route.cost==0)
      {
          return TRUE;
      }
      else
      {
      return FALSE;
      }
   }

    void insertTable(tableLS* tempTable)
    {
      uint16_t i= 0;
      for(i=0;routingTable[i].destination!=0;i++)
      {

      }
      routingTable[i].destination = tempTable[0].destination;
      routingTable[i].nextHop = tempTable[0].nextHop;
      routingTable[i].cost = tempTable[0].cost+1;
      call RoutingTable.insert(tempTable[0].destination,routingTable[i]);
      sendLSP();

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