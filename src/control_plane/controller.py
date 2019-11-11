from p4utils.utils.topology import Topology
from p4utils.utils.sswitch_API import SimpleSwitchAPI

class NCacheController(object):

    def __init__(self):
        self.topo = Topology(db="topology.db")


    def main(self):
        pass

if __name__ == "__main__":
    controller = NCacheController().main()
