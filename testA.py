from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("tuna-melt.topo");
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

    #determine the "well known address" and "well know port" of the server
    well_known_mote = 1;
    well_known_port=42;
    other_well_known_mote=7;
    other_well_known_port = 99;

    # After sending a ping, simulate a little to prevent collision.

    s.runTime(300);
    s.testServer(well_known_mote,well_known_port); #needs two, node i connects to port j
    s.runTime(60);

    s.testClient(4,well_known_mote,well_known_port,15,150);# Client at node 4 binds to port 15 and attemps to send data to node 1 at port 2 
    s.runTime(1);
    s.runTime(1000);



if __name__ == '__main__':
    main()
