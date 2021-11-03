/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    components new TimerMilliC() as NeighboorTimer;
    components new TimerMilliC() as RoutingTimer;
    components new TimerMilliC() as TCPTimer;
    components RandomC as Random;



    Node -> MainC.Boot;
    Node.RandomTimer -> Random;
    Node.NeighboorTimer -> NeighboorTimer;
    Node.RoutingTimer -> RoutingTimer;
    Node.TCPTimer -> RoutingTimer;

    Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;
    
    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    components new ListC(pack,64) as PacketListC;
    Node.PacketList -> PacketListC;

    components new ListC(LSP,20) as LinkStateInfoC;
    Node.LinkStateInfo -> LinkStateInfoC;

    components new ListC(neighboorDiscovery*,64) as NeighboorList1C;
    Node.NeighboorList1 -> NeighboorList1C;

    components new ListC(neighboorDiscovery,64) as NeighboorListC;
    Node.NeighboorList -> NeighboorListC;

     components new ListC(tableLS,64) as ConfirmedC;
    Node.Confirmed -> ConfirmedC;

     components new ListC(tableLS,64) as TentativeC;
    Node.Tentative -> TentativeC;

    components new PoolC(neighboorDiscovery,64) as NeighboorPoolC;
    Node.NeighboorPool -> NeighboorPoolC;

    components new HashmapC(tableLS,255) as RoutingTableC;
    Node.RoutingTable -> RoutingTableC;

    components new HashmapC(tableLS,255) as BackUpRoutingTableC;
    Node.BackUpRoutingTable -> BackUpRoutingTableC;
   
    components new HashmapC(uint16_t, 64) as RoutingTable1C;
    Node.RoutingTable1 -> RoutingTable1C;

    //project 3
    components new HashmapC(socket_t,10) as socketTable;
    Node.socketTable->socketTable;

    components new ListC(socket_t,30) as socketList;
    Node.socketList-> socketList;
   
}
