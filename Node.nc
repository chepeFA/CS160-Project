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
#include "includes/socket.h"

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
   uses interface Hashmap<socket_t> as socketTable;
   uses interface List<socket_t> as socketList;
   uses interface Queue<pack> as packetQueue;



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


    //Project 3
    TCP_Pack TCP_pack;
    socket_t fdw;
    pack flying;


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


   //prototypes Project 3
   socket_t getSocket();
   error_t bindClient(socket_t fd, socket_addr_t *addr,socket_addr_t *server);
   socket_t getSocket1(uint8_t destPort, uint8_t srcP);
   void connect(socket_t fd);
   void makePack1(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
   void finishConnecting(socket_t skt);
   socket_t getServerSocket(uint8_t destPort);
   void TCP_Mechanism(pack * msg);
   void info(uint16_t dest,uint16_t destPort, uint16_t srcPort, uint16_t transfer);








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
      pack another = call packetQueue.head();
      pack sentPacket = flying;
      pack p;
      TCP_Pack *tcpPack = (TCP_Pack*)(sentPacket.payload);
      socket_t skt = getSocket1(tcpPack->srcPort,tcpPack->destPort);
      dbg(TRANSPORT_CHANNEL,"info in package: tcp srcPort: %d tcp destPort: %d  \n",tcpPack->srcPort,tcpPack->destPort);
      //dbg(TRANSPORT_CHANNEL,"Sent packet payload: %s",sentPacket.payload);
      //dbg();

      if(skt.dest.port)
      {
            //dbg(TRANSPORT_CHANNEL, "PACKET DROPPED, RETRANSMITTING PACKET\n");
            dbg(GENERAL_CHANNEL,"socket info skt.dest.addr %d\t skt.dest.port %d \t \n",skt.dest.addr,skt.dest.port);
            call socketList.pushback(skt);

            makePack(&sentPacket,TOS_NODE_ID,skt.dest.addr,MAX_TTL,PROTOCOL_TCP,0,tcpPack,PACKET_MAX_PAYLOAD_SIZE);
            call TCPTimer.startOneShot(140000);
            //if(call RoutingTable1.get(skt.dest.addr))
            //{
            call Sender.send(sentPacket,skt.dest.addr);
            //}
            //else
            dbg(TRANSPORT_CHANNEL,"Can't find route to server\n");
      }



    
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
            /*
          
           

         }  
          */

          else if(myMsg->protocol == PROTOCOL_TCP)
          {
              TCP_Mechanism(myMsg);
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
       dbg("Forwarding: %d \n",call RoutingTable1.get(destination));
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

   event void CommandHandler.setTestServer(uint16_t port){

   socket_t skt;
   socket_addr_t myAddress;

   myAddress.addr = TOS_NODE_ID;
   myAddress.port = port;

   skt.src = myAddress;
   skt.state=LISTEN;
   skt.nextExpected=0;

    call socketList.pushback(skt);
    dbg(GENERAL_CHANNEL,"Source: %d \t Destination:%d \t \n",TOS_NODE_ID,port);
    dbg(GENERAL_CHANNEL,"socket info: myAddress.addr: %d, myAddress.port:%d \n",myAddress.addr,myAddress.port);
   


}
void info(uint16_t dest,uint16_t destPort, uint16_t srcPort, uint16_t transfer)
{
   dbg(GENERAL_CHANNEL,"dest:%d\t destPort:%d\t srcPort:%d\t transfer:%d  \n",dest,destPort,srcPort,transfer);
}


   event void CommandHandler.setTestClient(uint16_t dest,uint16_t destPort, uint16_t srcPort, uint16_t transfer){
     

   socket_t skt;
   socket_addr_t myAddress;
   //uint16_t arguments[4];

   myAddress.addr = TOS_NODE_ID;
   myAddress.port = srcPort;

   skt.dest.port = destPort;
   skt.dest.addr=dest;
   skt.transfer=transfer;

   dbg(GENERAL_CHANNEL,"dest: %d destPort: %d srcPort: %d transfer: %d  \n",dest,destPort,srcPort,transfer);

   call socketList.pushback(skt);
   connect(skt);
   info(dest,destPort,srcPort,transfer);

   }

   event void CommandHandler.clientClose(uint16_t dest,uint16_t destPort,uint16_t srcPort)
   {
      //socket_addr_t skt_addr;
      //socket_addr_t skt_server;
      ///socket_store_t tempsocket;
      //socket_t fd;

   }

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
   // dbg(ROUTING_CHANNEL,"ID: %d \n",TOS_NODE_ID);
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
  //dbg(ROUTING_CHANNEL,"my payload : %s \n",payload);
   call Sender.send(sendPackage,AM_BROADCAST_ADDR);

  }


  //PROJECT 3 FUNCTIONS --------------------------
  

  socket_t getSocket1(uint8_t destPort, uint8_t srcPort)
  {

      socket_t sk;
      bool found;
      socket_t temp;
      uint16_t i=0;
      uint16_t size = call socketList.size();
      dbg(GENERAL_CHANNEL,"In getsocket function. destPort: %d \t srcPort: %d \n");
      while(i<size)
      {

        sk = call socketList.get(i);
        if(sk.dest.port==srcPort && sk.src.port == destPort && sk.state!=LISTEN)
        { 
          //temp=sk;
          //call socketList.remove(i);
          //return sk;
          found=true;
          call socketList.remove(i);
          break;
        }
      i++;
      }

      if(found==true)
      {
        return sk;
      }
      else
      dbg(TRANSPORT_CHANNEL,"Socket not found \n");

  }


  socket_t getServerSocket(uint8_t destPort)
  {
      socket_t sk;
      uint16_t i =0;
      uint16_t size = call socketList.size();
      while(i<size)
      {
        sk = call socketList.get(i);
        if(sk.src.port == destPort && sk.state ==LISTEN)
        {
            return sk;
        }

      i++;
      }
  }


  void connect(socket_t fd)
  {
    pack msg;
    TCP_Pack* tcpPack;
    socket_t temp =fd;
    tcpPack = (TCP_Pack*)(msg.payload);

    tcpPack -> destPort = temp.dest.port;
    tcpPack -> srcPort = temp.src.port;
    tcpPack->ACK=0;
    tcpPack->seq=1;
    tcpPack->flag = SYN_FLAG;
    makePack(&msg,TOS_NODE_ID,temp.dest.addr,MAX_TTL,PROTOCOL_TCP,0,tcpPack,PACKET_MAX_PAYLOAD_SIZE);
    temp.state = SYN_SENT;
    dbg(GENERAL_CHANNEL,"MSG payload: %s", msg.payload);

  //dbg(GENERAL_CHANNEL,"Node %u state is %u \n",temp.src.addr,temp.state);
    //dbg(GENERAL_CHANNEL,"Client is trying to connet \n");
    if(call RoutingTable1.get(temp.dest.addr))
    {


    call Sender.send(msg,temp.dest.addr);
    }
    else
    dbg(ROUTING_CHANNEL, "Route to destination server not found...\n");




  }

  void finishConnecting(socket_t fd)
  {
    uint16_t i=0;
    TCP_Pack *tcpPack;
    pack msg;
    socket_t skt =fd;
    tcpPack = (TCP_Pack*)(msg.payload);
    tcpPack->destPort = skt.dest.port;
    tcpPack->srcPort = skt.src.port;
    tcpPack->flag = DATA_FLAG;
    tcpPack->seq=0;
    


     while(i<6 && i<=skt.effectiveWindow)
    {
      tcpPack->payload[i]=i;
      i++;

      }


   

    tcpPack->ACK=i;
    makePack(&msg, TOS_NODE_ID, skt.dest.addr, MAX_TTL, PROTOCOL_TCP, 0, tcpPack, 6);
    dbg(ROUTING_CHANNEL, "Node %u State is %u \n", skt.src.addr, skt.state);
    makePack(&flying, TOS_NODE_ID, skt.dest.addr, MAX_TTL, PROTOCOL_TCP, 0,tcpPack , PACKET_MAX_PAYLOAD_SIZE);
    

    dbg(ROUTING_CHANNEL, "SERVER CONNECTED\n");

    call TCPTimer.startOneShot(150000);
    call Sender.send(msg,call RoutingTable1.get(skt.dest.addr));






  }

  void TCP_Mechanism(pack *msg)
  {
 
  TCP_Pack * tcp_msg= (TCP_Pack*)(msg->payload);
  TCP_Pack *newTCP;
  pack p;
  uint8_t srcPort=0;
  uint8_t seq=0;
  uint8_t destPort=0;
  uint8_t ACK;
  uint8_t flag;
  socket_t skt;
  uint16_t i;
  uint16_t j;
  srcPort = tcp_msg->srcPort;
  destPort = tcp_msg->destPort;
  seq = tcp_msg->seq;
  ACK = tcp_msg->ACK;
  flag  = tcp_msg->flag;
 

  if(flag == SYN_FLAG || flag == SYN_ACK_FLAG || flag == ACK_FLAG)
  {

 
     if(flag == SYN_FLAG)
  {
    dbg(TRANSPORT_CHANNEL,"SYN Received  \n");
    skt = getServerSocket(destPort);
    //uint8_t sktDestAddr = call RoutingTable1.get(skt.dest.addr);
    if(skt.src.port && skt.state == LISTEN)
    {
      skt.state=SYN_RCVD;
      skt.dest.port = srcPort;
      skt.dest.addr = msg->src;
      call socketList.pushback(skt);

      newTCP= (TCP_Pack *)(p.payload);
      newTCP->destPort = skt.dest.port;
      newTCP ->srcPort = skt.src.port;
      newTCP->seq=1;
      newTCP->ACK=seq+1;
      newTCP->flag = SYN_ACK_FLAG;
      makePack(&p,TOS_NODE_ID,skt.dest.addr,MAX_TTL,PROTOCOL_TCP,0,newTCP,6);
      dbg(TRANSPORT_CHANNEL,"SYN ACK was sent \n");
      call Sender.send(p,call RoutingTable1.get(skt.dest.addr));


    }

    else if(flag == SYN_ACK_FLAG)
    {
    dbg(TRANSPORT_CHANNEL,"SYN ACK Received \n");
    skt = getSocket1(destPort,srcPort);
    skt.state=ESTABLISHED;
    call socketList.pushback(skt);
    newTCP = (TCP_Pack*)(p.payload);
    newTCP->destPort = skt.dest.port;
    newTCP->srcPort = skt.src.port;
    newTCP->seq=1;
    newTCP->ACK=seq+1;
    newTCP ->flag  = ACK_FLAG;
    dbg(TRANSPORT_CHANNEL,"ACK sent \n");
    makePack(&p,TOS_NODE_ID,skt.dest.addr,MAX_TTL,PROTOCOL_TCP,0,newTCP,6);
    call Sender.send(p,call RoutingTable1.get(skt.dest.addr));

    finishConnecting(skt);



    }

    else if(flag==ACK_FLAG)
    {
    dbg(TRANSPORT_CHANNEL,"ACK was received. Connection is finalizing\n");
    skt = getSocket1(destPort,srcPort);
    if(skt.src.port && skt.state==SYN_RCVD)
    {
        skt.state=ESTABLISHED;
        call socketList.pushback(skt);
    }



    }

    if(flag==DATA_FLAG || flag==DATA_ACK_FLAG)
    {



    if(flag==DATA_FLAG)
    {
      dbg(TRANSPORT_CHANNEL,"Data Received\n");
      skt = getSocket1(destPort,srcPort);

      if(skt.state==ESTABLISHED)
      {
       newTCP = (TCP_Pack*)(p.payload);

       if(tcp_msg->payload[0]!=0 && seq==skt.nextExpected)
       {
        i = skt.lastRcvd + 1;
        j=0;
        do
        {
          dbg(TRANSPORT_CHANNEL,"Writing to the received buffer %d \n",i);
          skt.rcvdBuff[i]=tcp_msg->payload[j];
          skt.lastRcvd = tcp_msg->payload[j];
          i++;
          j++;


        }while(j<tcp_msg->ACK);

       }
       else
       {
         i =0;
        
           while(i<tcp_msg->ACK);
           {
              skt.rcvdBuff[i] = tcp_msg->payload[i];
              skt.lastRcvd = tcp_msg->payload[i];
              i++;

              }

       
       }
       //buffer size = 64;
       skt.effectiveWindow = 64 -(skt.lastRcvd +1);
       skt.nextExpected = seq+1;

       call socketList.pushback(skt);
       newTCP ->destPort = skt.dest.port;
       newTCP->srcPort = skt.src.port;
       newTCP->seq = seq;
       newTCP ->ACK = seq+1;
       newTCP ->lastAcked = skt.lastRcvd;
       newTCP ->effectiveWindow = skt.effectiveWindow;
       newTCP->flag= DATA_ACK_FLAG;
       dbg(TRANSPORT_CHANNEL,"Sendind DATA ACK FLAG \n");
       makePack(&p,TOS_NODE_ID,skt.dest.addr,MAX_TTL,PROTOCOL_TCP,0,newTCP,6);
       call Sender.send(p,call RoutingTable1.get(skt.dest.addr));





    
    }
    }

    else if(flag==DATA_ACK_FLAG)
    {
      dbg(TRANSPORT_CHANNEL,"DATA ACT was received. LAST ACKED: %d \n",tcp_msg->lastAcked);
        skt = getSocket1(destPort,srcPort);
        if(skt.state==ESTABLISHED)
        {
        if(tcp_msg->window!=0 && tcp_msg->lastAcked !=skt.effectiveWindow)
        {
            dbg(TRANSPORT_CHANNEL, "SENDING NEXT DATA\n");
            newTCP = (TCP_Pack*)(p.payload);
            i = tcp_msg->lastAcked+1;
            j=0;
            while(j<tcp_msg->window && j<6 && i<=skt.effectiveWindow)
            { 

              dbg(TRANSPORT_CHANNEL, "Writing to Payload: %d\n", i);
              newTCP->payload[j]=i;
              i++;
              j++;

            }

            call socketList.pushback(skt);
            newTCP->flag = DATA_FLAG;
            newTCP->destPort = skt.dest.port;
            newTCP->srcPort = skt.src.port;
            newTCP->ACK = (i-1)-(tcp_msg->lastAcked);
            newTCP->seq = ACK;
             makePack(&p, TOS_NODE_ID, skt.dest.addr, MAX_TTL, PROTOCOL_TCP, 0, newTCP, PACKET_MAX_PAYLOAD_SIZE);     
                                        
            makePack(&flying, TOS_NODE_ID, skt.dest.addr, MAX_TTL, PROTOCOL_TCP, 0, newTCP, PACKET_MAX_PAYLOAD_SIZE);

            call TCPTimer.startOneShot(150000);
            call Sender.send(p,call RoutingTable1.get(skt.dest.addr));

        }
        else
        {
          dbg(TRANSPORT_CHANNEL,"ALL DATA SENT, CLOSING CONNECTION \n");
          skt.state = FIN_FLAG;
          call socketList.pushback(skt);
          newTCP=(TCP_Pack*)(p.payload);
          newTCP->destPort = skt.dest.port;
          newTCP->srcPort = skt.src.port;
          newTCP->seq=1;
          newTCP->ACK=seq+1;
          newTCP->flag = FIN_FLAG;
          makePack(&p,TOS_NODE_ID,skt.dest.addr,MAX_TTL,PROTOCOL_TCP,0,newTCP,PACKET_MAX_PAYLOAD_SIZE);
          call Sender.send(p,call RoutingTable1.get(skt.dest.addr));

        }


      }
    
    }




  }

    if(flag==FIN_FLAG || flag == FIN_ACK )
    {
        if(flag==FIN_FLAG)
        {
          dbg(TRANSPORT_CHANNEL,"RECEIVED FIN REQUEST");
          skt=getSocket1(destPort,srcPort);
          skt.state=CLOSED;
          skt.dest.port=srcPort;
          skt.dest.addr=msg->src;
          newTCP = (TCP_Pack*)(p.payload);
          newTCP->destPort = skt.dest.port;
          newTCP->srcPort = skt.src.port;
          newTCP->seq=1;
          newTCP->ACK=seq+1;
          newTCP->flag = FIN_ACK;
          dbg(TRANSPORT_CHANNEL, "CONNECTION CLOSING, DATA RECEIVED: \n");

          makePack(&p, TOS_NODE_ID, skt.dest.addr, MAX_TTL, PROTOCOL_TCP, 0, newTCP, PACKET_MAX_PAYLOAD_SIZE);
          call Sender.send(p,call RoutingTable1.get(skt.dest.addr));


        }
    }

    if(flag==FIN_ACK)
    {
      dbg(TRANSPORT_CHANNEL,"Got FIN ACK\n");
      skt=getSocket1(destPort,srcPort);
      skt.state=CLOSED;
    }









  }

  }


  }



  void makePack1(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length)
  {
      Package->src = src;
    Package->dest = dest;
    Package->TTL = TTL;
    Package->seq = seq;
    Package->protocol = protocol;
    memcpy(Package->payload, payload, length);
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