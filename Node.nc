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

//struct pj1
typedef nx_struct neighboorDiscovery{ //first two fields are for nd header
nx_uint16_t petition;
nx_uint16_t sequenceNumber;
nx_uint16_t sourceAddress;  //last two fields are for link layer headers
nx_uint16_t destinationAddress;
nx_uint16_t node;
nx_uint16_t age;
}neighboorDiscovery;


//struct pj2
typedef nx_struct tableLS{
  nx_uint8_t destination;
  nx_uint8_t nextHop;
  nx_uint8_t cost;
}tableLS;

typedef nx_struct link_state_pack{
  nx_uint8_t id;
  nx_uint8_t numNeighbors;
  nx_uint8_t age;
  nx_uint8_t neighbors[PACKET_MAX_PAYLOAD_SIZE - 3];
  //costs array corresponding to neighbor links: not needed since assume all links have same cost
}LSP;



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
   uses interface List<LSP> as LinkStateInfo;
   uses interface List<tableLS> as Confirmed;
   uses interface List<tableLS> as Tentative;
   uses interface Hashmap<tableLS> as BackUpRoutingTable;
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
   uint8_t neighboors[17];
  // uint16_t temp;

   //Project 2
    tableLS routingTable[255]={0}; //initialize all structs fields to zero.
    uint16_t seqNumberLSA=0;
    uint16_t LSTable[20][20];
   


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
   void sendLSPacket();
   void updateLSTable(uint8_t * payload, uint16_t source);
   uint16_t minDist(uint16_t dist[], bool sptSet[]);
   void initLSTable();

   bool isInLinkStateInfo(LSP);
   bool isUpdatedLSP(LSP);
   void updateLSP(LSP);
   void sortLinkStateInfo();
   error_t addLSP(LSP);
   void floodLSP();
   uint8_t getPos(uint8_t id);
   void updateLSP(LSP lsp);
   void updateAgesNodes();
   uint8_t posInTentative(uint8_t nodeid);
   bool isNextHop(uint8_t id);
   uint8_t findNextHopTo(uint8_t dest);
   bool inTentative(uint8_t);
   bool inConfirmed(uint8_t);
   void updateRoutingTable();
   void clearConfirmed();
   uint8_t minInTentative();
   void updateAges();
   void printLinkStateInfo();








   event void Boot.booted(){

       call AMControl.start();
      
        dbg(GENERAL_CHANNEL, "Booted. \n");
        //call NeighboorTimer.startPeriodic(20000);
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      //   initLSTable();
         //start neighbor discovery and routing timer as soon as radio is on
     call NeighboorTimer.startPeriodic(1000);

      //floodLSP();
     // call RoutingTimer.startOneShot(90000);
        
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
  // initLSTable();
 floodLSP();
  computeDijkstra();
  updateAges();


   }



   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
   {
   tableLS route[1];
   
      //dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack))
      {
         pack* myMsg=(pack*) payload;
        neighboorDiscovery *nnn;
        LSP* receivedLSP = (LSP*) myMsg->payload;
        LSP lsp = *receivedLSP;
      

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
            //  makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_PINGREPLY,  myMsg->seq, (uint8_t *)myMsg->payload, sizeof(myMsg->payload));   

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
                  //nodeNeighborCost();
                  n.node = myMsg->src;
                  n.age=0;
                  call NeighboorList.pushback(n);
                //   LSTable[TOS_NODE_ID - 1][myMsg->src - 1] = 1;
                    //sendLSPacket();


                  //pj2 
                 // nodeNeighborCost();

                }
         }

         
       
         
      }
         else if(myMsg->dest == TOS_NODE_ID) //this package is for me
         {

           // cost++;
            dbg(FLOODING_CHANNEL," packet from %d.payload: %s \n",myMsg->src,myMsg->payload);
            
           // temp=cost;

          //  if(myMsg->protocol != PROTOCOL_CMD)
            //{
            // pushPack(*myMsg);
            //}

            if(myMsg->protocol == PROTOCOL_PING)
            {

             // uint32_t nexxxtHop = call RoutingTable.get(myMsg->src);
           
               //dbg(NEIGHBOR_CHANNEL," in protocol ping TOS_NODE_ID \n");
              // dbg(NEIGHBOR_CHANNEL,"sending ping to node: %d",myMsg->src);

               makePack(&sendPackage,TOS_NODE_ID,myMsg->src,MAX_TTL,PROTOCOL_PINGREPLY,sequenceNumber,(uint8_t *)myMsg->payload,sizeof(myMsg->payload));
              sequenceNumber++;
               pushPack(sendPackage);
               //dbg(FLOODING_CHANNEL," packet from %d, destination %d \n",myMsg->src,myMsg->dest);
             
              //working on 10.08 as part of pj1
            call Sender.send(sendPackage,AM_BROADCAST_ADDR);


              
           
              
            }

            else if(myMsg->protocol == PROTOCOL_PINGREPLY)
            {

              dbg(NEIGHBOR_CHANNEL,"Ping is coming from %d \n",myMsg->src);
            }  
            /*
            else if(myMsg->protocol == PROTOCOL_LINKSTATE)
         {
        
            if(isInLinkStateInfo(lsp))
            {
              if(isUpdatedLSP(lsp))
              {

                updateLSP(lsp);
              }
              else
              {
               return msg;
              }
            }
            else
            {
            addLSP(lsp);


            }

            //sortLinkStateInfo();

         }   */


            
         }

         else //Broadcasting
         {
         tableLS b;
         b = call RoutingTable.get(myMsg->src);
            //cost++;
           //makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, myMsg->protocol, myMsg->seq, (uint8_t *)myMsg->payload, sizeof(myMsg->payload)); 
            makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->seq, (uint8_t *)myMsg->payload, sizeof(myMsg->payload));
            //dbg(FLOODING_CHANNEL,"Rebroadcasting again. We are in node:  %d, going to,  Destination: %d \n",TOS_NODE_ID,myMsg->dest);
            pushPack(sendPackage);

           //working from pj 1 
           call Sender.send(sendPackage, AM_BROADCAST_ADDR);
          

           //if(call RoutingTable1.get(myMsg->dest))
           //{
             // call Sender.send(sendPackage,call RoutingTable1.get(myMsg->dest));
           //}
           //else{
           //dbg(ROUTING_CHANNEL, "Route not found...\n");
           //}
         }
             return msg;

      }


             dbg(GENERAL_CHANNEL, "Unknown Packet Type %d %s \n", len);
             return msg;

}

      
   

   


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
    
  

   }



   event void CommandHandler.printNeighbors(){

   printNeighborList();
   //dbg(GENERAL_CHANNEL,"cost is: %d \n",cost);

   }

   event void CommandHandler.printRouteTable(){
  printLinkStateInfo();
   printRoutingTable();
  
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
 // dbg(GENERAL_CHANNEL,"About to start finding neighbors\n");

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


   


   message = "n";
   makePack(&sendPackage,TOS_NODE_ID,AM_BROADCAST_ADDR,2,PROTOCOL_PING,1,(uint8_t *)message,(uint8_t) sizeof(message));
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

   /*
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
   */

   bool isN(uint16_t src)
   {
   uint16_t sizeList = call NeighboorList.size();
   uint16_t i=0;
   neighboorDiscovery nx;

      if(!call NeighboorList.isEmpty())
      {
         //neighboorDiscovery nx;
        // uint16_t i, sizeList = call NeighboorList.size();
         
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
      }
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

   void initLSTable()
   {
   uint16_t i, j;
        for(i = 0; i < 20; i++){
            for(j = 0; j < 20; j++){
                    LSTable[i][j] = 9999;                           // Initialize all link state table values to infinity(20)
            }
        }
   }

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
    uint8_t i=0, size = call RoutingTable.size();
    tableLS entry;

    uint32_t *keys = call RoutingTable.getKeys();

    //printf("\n\t\t\t    Routing Table for node %d\n", TOS_NODE_ID);
    dbg(ROUTING_CHANNEL,"Routing Table for node %d \n Destination:  \t Cost:  \t Next Hop: \n",TOS_NODE_ID);
    while(i < size) {
      entry = call RoutingTable.get(keys[i]);
     // printf("(%d, %d, %d)\", entry.destination, entry.cost, entry.nextHop);
     printf("%d, \t  \t %d, \t \t %d \t \n",entry.destination,entry.cost,entry.nextHop);
      i++;
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


    void sendLSPacket()
    {
      char payload[255];
        char tempC[127];
        uint16_t i, size = call NeighboorList.size();          
        neighboorDiscovery neighbor;      
        for(i = 0; i < size; i++){
            neighbor = call NeighboorList.get(i);
            sprintf(tempC, "%d", neighbor.node);
            strcat(payload, tempC);
            strcat(payload, ",");
        }
        
        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 50, PROTOCOL_LINKSTATE, sequenceNumber,
                (uint8_t *) payload, (uint8_t)sizeof(payload));

        sequenceNumber++;
        pushPack(sendPackage);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
    }



    void computeDijkstra()
    {

    tableLS current, a,b;
    LSP lsp;
    uint8_t currentPos, tentativePos, minTentative, nextHop =0,i=0;


    //distance to my self is zero
    current.destination=TOS_NODE_ID;
    current.cost = 0;
    current.nextHop=0;

    call Confirmed.pushback(current);

    do
    {

      currentPos = getPos(current.destination);
      lsp = call LinkStateInfo.get(currentPos);

      while(i<lsp.numNeighbors)
      {
      a.destination = lsp.neighbors[i];
      a.cost = current.cost +1;

      if(isNextHop(a.destination))
      {
        nextHop = a.destination;
      }
      else
      {
      nextHop = findNextHopTo(a.destination);
      }

      if(!inTentative(a.destination) && !inConfirmed(a.destination))
      {
        call Tentative.pushback(a);
      }

      else if(inTentative(a.destination))
      {
        tentativePos = posInTentative(a.destination);
        b = call Tentative.get(tentativePos);
        if(a.cost<b.cost)
        {
          b.cost = a.cost;
          call Tentative.replace(tentativePos,b);
        }
      }



       i++;
      }


      minTentative = minInTentative();
      current = call Tentative.get(minTentative);
      call Tentative.remove(minTentative);
      call Confirmed.pushback(current);


    }while(call Confirmed.size()<call LinkStateInfo.size());

    updateRoutingTable();
    clearConfirmed();

        
    }

  void clearConfirmed() {
    while(!call Confirmed.isEmpty())
      call Confirmed.popfront();
  }

      void updateRoutingTable() {
    uint8_t i=0, j, size = call Confirmed.size();
    tableLS entry;
    uint32_t *keys;

    while(i < size) {
      entry = call Confirmed.get(i);
      call RoutingTable.insert(entry.destination, entry);
      i++;
    }

    //Cleanup
    i=0;
    keys = call RoutingTable.getKeys();
    while(i < call RoutingTable.size()) {
      entry = call RoutingTable.get(keys[i]);
      if(!inConfirmed(entry.destination)) {
        call RoutingTable.remove(keys[i]);
      }
      i++;
    }

  }

      uint8_t posInTentative(uint8_t nodeid) {
    tableLS entry;
    uint8_t i=0, size = call Tentative.size();

    while(i < size) {
      entry = call Tentative.get(i);
      if(entry.destination == nodeid) {
        return i;
      }
      i++;
    }
    return 0;
  }

    uint8_t minInTentative() {
    uint8_t i=1, size = call Tentative.size();
    uint8_t minPos = 0;
    tableLS entry, minEntry = call Tentative.get(0);

    while(i < size) {
      entry = call Tentative.get(i);
      if(entry.cost < minEntry.cost) {
        minEntry = entry;
        minPos = i;
      }
      i++;
    }
    return minPos;
  }

    bool isNextHop(uint8_t id) {
    uint8_t i=0, pos = getPos(TOS_NODE_ID);
    LSP lsp = call LinkStateInfo.get(pos);

    while(i < lsp.numNeighbors) {
      if(lsp.neighbors[i] == id) {
        return TRUE;
      }
      i++;
    }
    return FALSE;
  }


  

    

    void floodLSP() {

    LSP myLSP;
    uint8_t zzz=0;
    pack myPack;
    neighboorDiscovery nd;
    uint16_t a;
    uint8_t *neighbors;

    //Get a list of current neighbors
    uint8_t i, numNeighbors = call NeighboorList.size(); 
    dbg(GENERAL_CHANNEL,"About to start flooding \n");
    //=NeighboorList;// call NeighborDiscovery.getNeighbors();

   a=0;
   while(a<numNeighbors)
   {
    nd = call NeighboorList.get(a);
    neighboors[a] = nd.node;
    dbg(NEIGHBOR_CHANNEL,"Neighbor for node: %d,: %d, %d", TOS_NODE_ID, nd.node,neighboors[a]);
   a++;
   }
   neighbors = neighboors;

    //Encapsulate this list into a LSP
    myLSP.numNeighbors = numNeighbors;
    myLSP.id = TOS_NODE_ID;
    for(i = 0; i < numNeighbors; i++) {
      myLSP.neighbors[i] = neighbors[i];
    //  dbg(GENERAL_CHANNEL,"Neighbors: %d", myLSP.neighbors[i]);
      //zzz++;
      //if(zzz>10)
      //{
        //break;
      //}
    }
    myLSP.age = 5;

    //dbg(FLOODING_CHANNEL, "Flooding LSP\n", TOS_NODE_ID);

    //Encapsulate this LSP into a pack struct
    makePack(&myPack, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_LINKSTATE, 0, &myLSP, PACKET_MAX_PAYLOAD_SIZE);
    //Flood this pack on the network
    call Sender.send(myPack, myPack.dest);
  }


    
    //Adds a LSP to LinkStateInfo
  error_t addLSP(LSP lsp) { 

    uint16_t size = call LinkStateInfo.size();
    uint16_t maxSize = call LinkStateInfo.maxSize();

    if(isInLinkStateInfo(lsp)) {
      return EALREADY;
    }

    if(size == maxSize) {
      call LinkStateInfo.popfront();
      call LinkStateInfo.pushback(lsp);
      return SUCCESS;
    }
    else {
      call LinkStateInfo.pushback(lsp);
      return SUCCESS;
    }

    return FAIL;
  }

    bool inTentative(uint8_t nodeid) {
    tableLS entry;
    uint8_t i=0, size = call Tentative.size();

    while(i < size) {
      entry = call Tentative.get(i);
      if(entry.destination == nodeid) {
        return TRUE;
      }
      i++;
    }
    return FALSE;
  }


    bool inConfirmed(uint8_t nodeid) {
    tableLS entry;
    uint8_t i=0, size = call Confirmed.size();

    while(i < size) {
      entry = call Confirmed.get(i);
      if(entry.destination == nodeid) {
        return TRUE;
      }
      i++;
    }
    return FALSE;
  }


    bool isInLinkStateInfo(LSP lsp) {
    uint16_t size = call LinkStateInfo.size();
    uint8_t i=0;
    LSP comp;

    if(!call LinkStateInfo.isEmpty()) {
     
      while(i < size) {
        comp = call LinkStateInfo.get(i);
        if(comp.id == lsp.id) {
          return TRUE;
        }
        i++;
      }
    }
    return FALSE;
  }

    bool isUpdatedLSP(LSP lsp) {
    uint8_t i=0, pos = getPos(lsp.id);
    LSP comp = call LinkStateInfo.get(pos);

    if(lsp.numNeighbors == comp.numNeighbors) {
      while(i < comp.numNeighbors) {
        if(lsp.neighbors[i] != comp.neighbors[i])
          return TRUE;

          i++;
      }
      return FALSE;
    }
    return TRUE;
  }


    uint8_t getPos(uint8_t id) {
    uint8_t pos=0, size = call LinkStateInfo.size();
    LSP lsp;

    while(pos < size) {
      lsp = call LinkStateInfo.get(pos);
      if(id == lsp.id) {
        return pos;
      }
      pos++;
    }
    return 0;
  }

    void updateLSP(LSP lsp) {
    uint8_t pos = getPos(lsp.id);

    call LinkStateInfo.replace(pos, lsp);
  }

    uint8_t findNextHopTo(uint8_t dest) {
    uint8_t k=0, j=0, size = call Confirmed.size();
    uint8_t pos;
    tableLS entry;
    LSP lsp;
    //For each entry in Confirmed
    while(k < size) {
      //Search that entrys neigbors for 'dest'
      entry = call Confirmed.get(k);
      pos = getPos(entry.destination);
      lsp = call LinkStateInfo.get(pos);

      while(j < lsp.numNeighbors) {
        //If found, then return that entrys 'next_hop'
        if(lsp.neighbors[j] == dest) {
          return entry.nextHop;
        }
        j++;
      }
      k++;
    }
    return 0;
  } 


    void updateAges() {
    uint8_t i=0, size = call LinkStateInfo.size();
    LSP lsp;

    while(i < size) {
      lsp = call LinkStateInfo.get(i);
      if(lsp.age <= 1 || lsp.age > 5) {
        call LinkStateInfo.remove(i);
      }
      else {
        lsp.age--;
        call LinkStateInfo.replace(i, lsp);
      }
      i++;
    }
  }

    //Prints contents of LinkStateInfo
  void printLinkStateInfo() {
    uint8_t size = call LinkStateInfo.size();
    uint8_t i=0, j=0;
    LSP lsp;

    dbg(FLOODING_CHANNEL, "Node %d Link State Info(%d entries):\n", TOS_NODE_ID, size);

    while(i < size) {
      lsp = call LinkStateInfo.get(i);
      printf("\t\t\t\tNode %2d sent [ ", lsp.id);
      while(j < lsp.numNeighbors) {
        printf("%2d ", lsp.neighbors[j]);
        j++;
      }
      printf("]\n");
      i++;
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