from p4utils.utils.topology import Topology
from p4utils.utils.sswitch_API import SimpleSwitchAPI

class NCacheController(object):

    def __init__(self, sw_name):
        self.topo = Topology(db="../p4/topology.db")
        self.sw_name = sw_name
        self.thrift_port = self.topo.get_thrift_port(sw_name)
        self.controller = SimpleSwitchAPI(self.thrift_port)

    # simple forwarding rules for testing purposes
    def set_forwarding_tables(self):
        self.controller.table_add("l2_forward", "set_egress_port", ['1'], ['2'])
        self.controller.table_add("l2_forward", "set_egress_port", ['2'], ['1'])


    def main(self):
        self.set_forwarding_tables()

if __name__ == "__main__":
    controller = NCacheController('s1').main()
