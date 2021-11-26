from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("long_line.topo");#tuna-melt.topo b4
    #s.loadTopo("pizza.topo");
    #s.loadTopo("long_line.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");
    #s.loadNoise("some_noise.txt");
    #s.loadNoise("meyer-heavy.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.TRANSPORT_CHANNEL);
    s.addChannel(s.FLOODING_CHANNEL);
    s.addChannel(s.ROUTING_CHANNEL);

    #determine the "well known address" and "well know port" of the server
    well_known_mote = 1;
    well_known_port=42;
    other_well_known_mote=7;
    other_well_known_port = 99;

    # After sending a ping, simulate a little to prevent collision.
   # s.neighborDMP(1);
    #s.runTime(5);

    #s.neighborDMP(2);
    #s.runTime(50);
    #s.ping(1, 4, "Hi");
   # s.runTime(50);

    s.runTime(50);#300 b4
    s.testServer(well_known_mote,well_known_port); #needs two, node i connects to port j
    s.runTime(100);#100 b4

    s.testClient(4,well_known_mote,well_known_port,15,150);# Client at node 4 binds to port 15 and attemps to send data to node 1 at port 2 
    s.runTime(500);#100 b4
    #s.runTime(1000);
    #s.testServer(1,41);
    #s.runTime(10)

    #s.testServer(1,41);
    #s.runTime(10)

    #s.testServer(1,41);
    #s.runTime(10)


if __name__ == '__main__':
    main()
