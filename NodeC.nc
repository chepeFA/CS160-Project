/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 * 
 */ 

#include <Timer.h>

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(6);
    components new TimerMilliC() as myTimerC;
    
   Node -> MainC.Boot;
    
   Node.Receive -> AMReceiverC;

   Node.PeriodicTimer -> myTimerC;

   components ActiveMessageC;
   Node.AMControl -> ActiveMessageC;

   components SimpleSendC;
   Node.Sender -> SimpleSendC;
   
   components new ListC(pack, 64) as PacketListC;
   Node.PacketList -> PacketListC;
   
   components new ListC(neighbor*, 64) as NeighborListC;
   Node.NeighborList -> NeighborListC;
   
   components new PoolC(neighbor, 64) as NeighborPoolC;
   Node.NeighborPool -> NeighborPoolC;
   
   components RandomC as Random;
   Node.Random -> Random;
}