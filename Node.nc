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

   //PROJECT 3
   uses interface Timer<TMilli> as TCPTimer;

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
   bool finalDestination;
  // uint16_t temp;

   //Project 2
    tableLS routingTable[255]={0}; //initialize all structs fields to zero.
    uint16_t seqNumberLSA=0;
    uint16_t LSTable[20][20];
    uint16_t totalCost[20];
   


   // Prototypes Project 1
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   void findNeighboors();
   bool seenPackage(pack *package);
   void pushPack(pack package);
   bool isN(uint16_t src);
   void printNeighborList();

   // Prototypes Project 2
   void sendLSP();
   void Dijkstra();
   void forwarding(pack* Package);
   void printLSTable();
   void printRoutingTable();
   void printRoutingTable1();
   void sendLSPacket();
   void updateLSTable(uint8_t * payload, uint16_t source);
   uint16_t minDist(uint16_t dist[], bool sptSet[]);
   void initLSTable();
   void floodLSP();
   uint8_t getPos(uint8_t id);
   uint8_t findNextHopTo(uint8_t dest);
   void printLinkStateInfo();








   event void Boot.booted(){

       call AMControl.start();
      
        dbg(GENERAL_CHANNEL, "Booted. \n");
        //call NeighboorTimer.startPeriodic(20000);
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      initLSTable();
         //start neighbor discovery and routing timer as soon as radio is on
       call NeighboorTimer.startPeriodic(10000);

       //floodLSP();
      //call RoutingTimer.startOneShot(80000);
        
      }else{
         //Retry until successful
         call AMControl.start();
      }
      call RoutingTimer.startPeriodic(20000);

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
 //floodLSP();
  //computeDijkstra();
  //updateAges();


   }

   event void TCPTimer.fired()
   {
   
   }



   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
   {
   tableLS route[1];
   
     // dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack))
      {
         pack* myMsg=(pack*) payload;
        neighboorDiscovery *nnn;
        LSP* receivedLSP = (LSP*) myMsg->payload;
        LSP lsp = *receivedLSP;
      // dbg(ROUTING_CHANNEL,"LSP received: %s \n",myMsg->payload);

        
      

         if(myMsg->TTL==0 || seenPackage(myMsg))
         {
          
         }
         
         else if(myMsg->dest == AM_BROADCAST_ADDR)
      {
          
           
            bool foundNeighbor;
            uint16_t i,sizeList;
            neighboorDiscovery* neighboor, *neighboor_ptr, *a;
            neighboorDiscovery nd,n;
           // dbg(GENERAL_CHANNEL,"In destination broadcast \n");

            if(myMsg->protocol == PROTOCOL_PING)
            {
              
              //cost++;
            makePack(&sendPackage, TOS_NODE_ID,AM_BROADCAST_ADDR,myMsg->TTL-1, PROTOCOL_PINGREPLY, myMsg->seq, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));
           //  makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_PINGREPLY, myMsg->seq, (uint8_t *)myMsg->payload, sizeof(myMsg->payload));   

               //sequenceNumber++;
               pushPack(sendPackage);
            
               call Sender.send(sendPackage, myMsg->src);
                //dbg(FLOODING_CHANNEL," packet from %d, destination %d \n",myMsg->src,myMsg->dest);
             // call Sender.send(sendPackage, AM_BROADCAST_ADDR);
          
            }


            //hearing back from a neighbor
            else if(myMsg->protocol == PROTOCOL_PINGREPLY)
            {
            sizeList =call NeighboorList.size();
           foundNeighbor=FALSE;
          
               i=0;
             
               while(i<sizeList)
                {
                nd = call NeighboorList.get(i);
                if(nd.node==myMsg->src)
                {
                nd.age=0;
                foundNeighbor=TRUE;
                }
                i++;
                }

                if(!foundNeighbor)
                {
                neighboor = call NeighboorPool.get();
                neighboor->node = myMsg->src;
                neighboor->age=0;
                call NeighboorList.pushback(*neighboor);
                }
                LSTable[TOS_NODE_ID - 1][myMsg->src -1]=1;//cost
                floodLSP();
         }

        else if(myMsg->protocol==PROTOCOL_LINKSTATE)
        {
          updateLSTable((uint8_t *)myMsg->payload,myMsg->src);                                  
          makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol,
          myMsg->seq, (uint8_t *)myMsg->payload, sizeof(myMsg->payload));

          pushPack(sendPackage);
          call Sender.send(sendPackage, AM_BROADCAST_ADDR);
        }

         
       
         
      }
         else if(myMsg->dest == TOS_NODE_ID) //this package is for me
         {
  
           finalDestination =TRUE;


            dbg(FLOODING_CHANNEL," packet from %d payload: %s \n",myMsg->src,myMsg->payload);
            //goto a;
            
  

        

            if(myMsg->protocol == PROTOCOL_PING)
            {

             // uint32_t nexxxtHop = call RoutingTable.get(myMsg->src);
           
               //dbg(NEIGHBOR_CHANNEL," in protocol ping TOS_NODE_ID \n");
              // dbg(NEIGHBOR_CHANNEL,"sending ping to node: %d",myMsg->src);

               makePack(&sendPackage,TOS_NODE_ID,myMsg->src,MAX_TTL,PROTOCOL_PINGREPLY,sequenceNumber,(uint8_t *)myMsg->payload,sizeof(myMsg->payload));
              sequenceNumber++;
               pushPack(sendPackage);
              
             
              //working on 10.08 as part of pj1
              //call Sender.send(sendPackage,AM_BROADCAST_ADDR);
              if(call RoutingTable1.get(myMsg->src))
              {
                dbg(ROUTING_CHANNEL,"Sending packet to next hop: %d \n",call RoutingTable1.get(myMsg->src));
                call Sender.send(sendPackage,call RoutingTable1.get(myMsg->src));
              }
              else
              dbg(ROUTING_CHANNEL, "Path not found\n");

              
           
              
          }

            else if(myMsg->protocol == PROTOCOL_PINGREPLY)
            {

             // dbg(NEIGHBOR_CHANNEL,"Ping is coming from %d \n",myMsg->src);
            }  
            
          
           

         }  



            
         }

         else //Broadcasting
         {
             makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->seq, 
                    (uint8_t *)myMsg->payload, sizeof(myMsg->payload));
              pushPack(sendPackage);
              if(call RoutingTable1.get(myMsg->dest)){
                dbg(ROUTING_CHANNEL, "Route found, Sending to next hop %d\n", call RoutingTable1.get(myMsg->dest));
                call Sender.send(sendPackage, call RoutingTable1.get(myMsg->dest));
            }else{
              //  dbg(ROUTING_CHANNEL, "Route not found...\n");
            }
         }
             return msg;

      }


             dbg(GENERAL_CHANNEL, "Unknown Packet Type %d %s \n", len);
             return msg;
             

}

      
   

   


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){

          finalDestination=FALSE;

       dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, sequenceNumber, payload, PACKET_MAX_PAYLOAD_SIZE);
      sequenceNumber++;
      pushPack(sendPackage);

      if(call RoutingTable1.get(destination)){
         dbg(ROUTING_CHANNEL, "Sending to next hop %d\n", call RoutingTable1.get(destination));
         call Sender.send(sendPackage, call RoutingTable1.get(destination));
      }
      else{
         dbg(ROUTING_CHANNEL, "Route to destination not found...\n");
      }

   }



   event void CommandHandler.printNeighbors(){

   printNeighborList();
   //dbg(GENERAL_CHANNEL,"cost is: %d \n",cost);

   }

   event void CommandHandler.printRouteTable(){
  //printLinkStateInfo();
  //printLSTable();
  printRoutingTable1();

  
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
   /*
   pack Package;
   char* message;
   neighboorDiscovery nd,t;
   uint16_t i=0;
   uint16_t sizeList= call NeighboorList.size();
 //dbg(GENERAL_CHANNEL,"About to start finding neighbors\n");

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
      if(t.age>3)
      {
         call NeighboorList.remove(i);
         sizeList--;
         i--;
      }
      i++;
    }
      
   
   //uint16_t i,sizeList,age;


   


   message = "help\n";
   makePack(&Package,TOS_NODE_ID,AM_BROADCAST_ADDR,2,PROTOCOL_PING,1,(uint8_t *)message,(uint8_t) sizeof(message));
   pushPack(Package);
   call Sender.send(Package,AM_BROADCAST_ADDR);
   //void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   */

   //beg of the function
   pack Package;
    char* message;

    if(!call NeighboorList1.isEmpty()) {
      uint16_t size = call NeighboorList1.size();
      uint16_t i = 0;
      uint16_t age = 0;
      neighboorDiscovery* neighbor_ptr;
      neighboorDiscovery* temp;
     
      //Age the NeighborList
      for(i = 0; i < size; i++) {
        temp = call NeighboorList1.get(i);
        temp->age++;
      }

      for(i = 0; i < size; i++) {
        temp = call NeighboorList1.get(i);
        age = temp->age;
        if(age > 5) {
          neighbor_ptr = call NeighboorList1.remove(i);
          //dbg("Project1N", "Node %d is older than 5 pings, dropping from list\n", neighbor_ptr->Node);
          call NeighboorPool.put(neighbor_ptr);
          i--;
          size--;
        }
      }
    }


   //end of the function
    message = "help\n";
   makePack(&Package,TOS_NODE_ID,AM_BROADCAST_ADDR,2,PROTOCOL_PING,1,(uint8_t *)message,(uint8_t) sizeof(message));
   pushPack(Package);
   call Sender.send(Package,AM_BROADCAST_ADDR);

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
            totalCost[i]=0;
        }
   }

     
       

  void printRoutingTable1()
  {
        uint16_t size = call RoutingTable1.size(), i=0, output;
        while(i < size){
            output = call RoutingTable1.get((uint32_t) i);
            dbg(ROUTING_CHANNEL, "Node: %d\t Next Hop: %d\t cost: %d\n", i, output,totalCost[i-1]);
            i++;
        }

        dbg(ROUTING_CHANNEL, "\n");
  }

    void updateLSTable(uint8_t * payload, uint16_t source){
        uint8_t *temp = payload;
        uint16_t length = strlen((char *)payload);      
        uint16_t i = 0;
        char buffer[5];
        while (i < length){
            if(*(temp + 1) == ' '){
                memcpy(buffer, temp, 1);
                temp += 2;
                i += 2;
                buffer[1] = '\0';
            }else if(*(temp + 2) == ' '){
               memcpy(buffer, temp, 2);
                temp += 3;
                i += 3;
                buffer[2] = '\0';
            }
            
                LSTable[source - 1][atoi(buffer) - 1] = 1;
               // totalCost[source-1][atoi(buffer) - 1] = 1;
        }

       Dijkstra();
    }

    void Dijkstra()
    {
        uint16_t myID = TOS_NODE_ID - 1, i, count, v, u;
        uint16_t dist[20];
        bool sptSet[20];
        int parent[20];
        int temp;

          for(i = 0; i < 20; i++){
            dist[i] = 9999;
            sptSet[i] = FALSE;
            parent[i] = -1;   
        }

        dist[myID] = 0;

         for(count = 0; count < 19; count++){
            u = minDist(dist, sptSet);
            sptSet[u] = TRUE;

            for(v = 0; v < 20; v++){
                if(!sptSet[v] && LSTable[u][v] != 9999 && dist[u] + LSTable[u][v] < dist[v]){
                    parent[v] = u;
                    dist[v] = dist[u] + LSTable[u][v];
                    totalCost[v]=dist[v];
                }
            }           
        }
        i=0;
        while( i < 20){
            temp = i;
            while(parent[temp] != -1  && parent[temp] != myID && temp < 20){
                temp = parent[temp];
            }
            if(parent[temp] != myID){
                call RoutingTable1.insert(i + 1, 0);
            }
            else
            {
                call RoutingTable1.insert(i + 1, temp + 1);
                //totalCost[i]+=1;
                }
                i++;

        }



    }

    uint16_t minDist(uint16_t dist[], bool sptSet[])
    {
      uint16_t min = 9999, minIndex = 18, i=0;
        while( i < 20){
            if(sptSet[i] == FALSE && dist[i] < min)
                min = dist[i], minIndex = i;
                i++;
        }
        return minIndex;
    }



    void printLSTable()
    {
      uint16_t i;                                    
        uint16_t j;
        for(i = 0; i < 20; i++){
            for(j = 0; j < 20; j++){
                if(LSTable[i][j] == 1)
                    dbg(ROUTING_CHANNEL, "Neighbors: %d and %d\n", i + 1, j + 1);
            }
        }
    }


   

    void sendLSPacket()
    {
      char payload[255];
        char tempC[127];
        uint16_t i=0, size = call NeighboorList.size();          
        neighboorDiscovery neighbor;      
        while(i < size){
            neighbor = call NeighboorList.get(i);
            sprintf(tempC, "%d", neighbor.node);
            strcat(payload, tempC);
            strcat(payload, ",");
            i++;
        }
        
        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 50, PROTOCOL_LINKSTATE, sequenceNumber,
                (uint8_t *) payload, (uint8_t)sizeof(payload));

        sequenceNumber++;
        pushPack(sendPackage);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
    }

    void floodLSP() {

    LSP myLSP;
    ///tableLS myLSP;
    uint8_t zzz=0;
    pack myPack;
    char* message;
    char payload[255];
    char tempC[127];
    
    neighboorDiscovery* ndd;
    uint16_t a;
    uint8_t *neighbors;

    //Get a list of current neighbors
    uint8_t i=0, numNeighbors = call NeighboorList.size(); 
   
    
   

    //dbg(GENERAL_CHANNEL,"Num of neighbors: %d \n",numNeighbors);
   

   while(i<17)
    {
        neighboors[i]=0;
        i++;
    }

   a=0;
   while(a<numNeighbors)
   {
 
    neighboorDiscovery nd = call NeighboorList.get(a);//get the neighbors for each node
 
    neighboors[a] = nd.node;

    sprintf(tempC, "%d", nd.node);
    strcat(payload,tempC);//strcat b4
    strcat(payload, " ");//strcat b4
    a++;

   }
   neighbors = neighboors;
   //dbg(ROUTING_CHANNEL,"Neighboors %d \n",neighboors);
    //Encapsulate this list into a LSP, use pointer here
    myLSP.numNeighbors = numNeighbors;
    myLSP.id = TOS_NODE_ID;
    dbg(ROUTING_CHANNEL,"ID: %d \n",TOS_NODE_ID);
    for(i = 0; i < numNeighbors; i++) {
      myLSP.neighbors[i] = neighbors[i];
    }
    myLSP.age = 5;
    //strcat(payload, myLSP);
  // dbg(ROUTING_CHANNEL, "Payload: %s \n", myLSP);

    //Encapsulate this LSP into a pack struct
   // makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_LINKSTATE, 0, &myLSP, PACKET_MAX_PAYLOAD_SIZE);
   // makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_LINKSTATE, 0, (uint8_t *)myLSP, PACKET_MAX_PAYLOAD_SIZE);
   makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 50, PROTOCOL_LINKSTATE, sequenceNumber,(uint8_t *) payload, (uint8_t)sizeof(payload));
    //dbg(ROUTING_CHANNEL,"my pack1 : %s \n",&myPack);
    //dbg(ROUTING_CHANNEL,"my pack2 : %s \n",myPack);
    //dbg(ROUTING_CHANNEL,"my pack3 : %s \n",&myLSP);
    //dbg(ROUTING_CHANNEL,"my pack4 : %s \n",myLSP);
    //dbg(ROUTING_CHANNEL,"my pack5 : %s \n",(uint8_t *)myLSP);
    //Flood this pack on the network
    //dbg(ROUTING_CHANNEL,"Dest: %d \n",myPack.dest); // flood to everybody
   // call Sender.send(myPack, myPack.dest);
  // dbg(GENERAL_CHANNEL,"Package send %s \n",sendPackage);
  sequenceNumber++;
  pushPack(sendPackage);
 // dbg(ROUTING_CHANNEL,"my payload : %s \n",(uint8_t *)payload);
  dbg(ROUTING_CHANNEL,"my payload : %s \n",payload);
   call Sender.send(sendPackage,AM_BROADCAST_ADDR);

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