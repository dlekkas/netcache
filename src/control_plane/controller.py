from p4utils.utils.topology import Topology
from p4utils.utils.sswitch_API import SimpleSwitchAPI
from scapy.all import sniff, Packet, Ether, IP, UDP, BitField, Raw

import threading
import struct
import random

VTABLE_NAME_PREFIX = 'vt'
VTABLE_SLOT_SIZE = 16   # in bytes
VTABLE_ENTRIES = 65536

HOTQUERY_MIRROR_SESSION = 100

NETCACHE_HOT_QUERY = 3



class NetcacheHeader(Packet):
    name = 'NcachePacket'
    fields_desc = [BitField('op', 0, 8), BitField('seq', 0, 32),
            BitField('key', 0, 128), BitField('value', 0, 1024)]


class NCacheController(object):

    def __init__(self, sw_name, vtables_num=8):
        self.topo = Topology(db="../p4/topology.db")
        self.sw_name = sw_name
        self.thrift_port = self.topo.get_thrift_port(self.sw_name)
        self.cpu_port = self.topo.get_cpu_port_index(self.sw_name)
        self.controller = SimpleSwitchAPI(self.thrift_port)

        self.vtables = []
        self.vtables_num = vtables_num

        # dictionary storing the index and bitmap for the register array
        # in the P4 switch that corresponds to each key
        self.key_map = {}

        self.setup()


    def setup(self):
        if self.cpu_port:
            self.controller.mirroring_add(HOTQUERY_MIRROR_SESSION, self.cpu_port)

        # spawn new thread to serve incoming udp connections
        # (i.e hot reports from the switch)
        #udp_t = threading.Thread(target=self.hot_reports_loop)
        #udp_t.start()


    def set_value_tables(self):
        # TODO(dimlek): do this with for loop maybe
        self.controller.table_add("vtable_0", "process_array_0", ['1'], [])
        self.controller.table_add("vtable_1", "process_array_1", ['1'], [])
        self.controller.table_add("vtable_2", "process_array_2", ['1'], [])
        self.controller.table_add("vtable_3", "process_array_3", ['1'], [])
        self.controller.table_add("vtable_4", "process_array_4", ['1'], [])
        self.controller.table_add("vtable_5", "process_array_5", ['1'], [])
        self.controller.table_add("vtable_6", "process_array_6", ['1'], [])
        self.controller.table_add("vtable_7", "process_array_7", ['1'], [])


    # TODO(dimlek): this function manages the mapping between between slots in
    # register arrays and the cached items by implementing the First Fit algorithm
    # described in Memory Management section of 4.4.2
    # currently it randomly chooses where to store values
    def dummy_fit(self, key, value_size):
        n_slots = (value_size / VTABLE_SLOT_SIZE) + 1
        if value_size <= 0:
            return False
        if key in self.key_map:
            return False

        # dummy logic - needs to change
        bitmaplist = []
        for i in range(n_slots):
            bitmaplist.append('1')
        for i in range(n_slots, self.vtables_num):
            bitmaplist.append('0')

        index = random.randint(0, VTABLE_ENTRIES-1)
        self.key_map[key] = (index, bitmaplist)
        return


    # converts a list of 1s and 0s represented as strings and converts it
    # to a bitmap using bitwise operations (this intermediate representation
    # of a list of 1s and 0s is used to avoid low level bitwise logic inside
    # core implementation logic)
    def convert_to_bitmap(self, strlist, bitmap_len):
        bitmap = 0
        # supports only bitmaps with multiple of 8 bits size
        if bitmap_len % 8 != 0:
            return bitmap
        for i in strlist:
            bitmap = bitmap << 1
            bitmap = bitmap | int(i)

        return bitmap


    # given a key and its associated value, we update the lookup table on
    # the switch and we also update the registers holding the values with
    # the value given as argument (stored in multiple slots)
    def insert_value(self, key, value):
        # find where to put the value for given key
        update = self.dummy_fit(key, len(value))
        # if key already exists then stop
        if update == False:
            return

        index, bitmaplist = self.key_map[key]
        # keep track of number of bytes of the value written so far
        cnt = 0
        # store the value of the key in the vtables of the switch while
        # incrementally storing a part of the value if the correspoding
        # bit of the bitmap is set
        for i in range(self.vtables_num):
            if bitmaplist[i] == '1':
                partial_val = value[cnt:cnt+VTABLE_SLOT_SIZE]
                self.controller.register_write(VTABLE_NAME_PREFIX + str(i),
                        index, self.str_to_int(partial_val))
                cnt += VTABLE_SLOT_SIZE

        bitmap = self.convert_to_bitmap(bitmaplist, self.vtables_num)
        self.controller.table_add("lookup_table", "set_lookup_metadata",
            [str(self.str_to_int(key))], [str(bitmap), str(index)])


    # converts a string to a bytes representation and afterwards returns
    # its integer representation of width specified by argument int_width
    # (seems hacky due to restriction to use python2.7)
    def str_to_int(self, x, int_width=VTABLE_SLOT_SIZE):
        if len(x) > int_width:
            # TODO(dimlek): error message needed here
            print "Overflow"

        # add padding with 0x00 if input string size less than int_width
        bytearr = bytearray(int_width - len(x))
        bytearr.extend(x.encode('utf-8'))
        return struct.unpack(">QQ", bytearr)[1]


    # given an arbitrary sized integer, the max width (in bits) of the integer
    # it returns the string representation of the number (also stripping it of
    # any '0x00' characters)
    def int_to_packed(self, int_val, max_width=128, word_size=32):
        num_words = max_width / word_size
        words = self.int_to_words(int_val, num_words, word_size)

        fmt = '>%dI' % (num_words)
        return struct.pack(fmt, *words).strip('\x00')

    def int_to_words(self, int_val, num_words=4, word_size=32):
        max_int = 2 ** (word_size*num_words) - 1
        max_word_size = 2 ** word_size - 1
        words = []
        for _ in range(num_words):
            word = int_val & max_word_size
            words.append(int(word))
            int_val >>= word_size
        words.reverse()
        return words


    # TODO(dimlek): implement the logic of evicting a specified key and its associated
    # value from the cache on the switch (update lookup tables and value registers)
    def evict_value(self, key):
        pass


    # used for testing purposes and static population of cache
    def dummy_populate_vtables(self):
        test_values_l = ["alpha", "beta", "gamma", "delta", "epsilon", "zeta",
                         "hita", "theta", "yiota", "kappa", "lambda", "meta"]
        test_keys_l = ["one", "two", "three", "four", "five", "six", "seven",
                       "eight", "nine", "ten", "eleven", "twelve"]
        cnt = 0
        for i in range(11):
            self.insert_value(test_keys_l[i], test_values_l[i])



    def recv_hot_report(self, pkt):
        # extract netcache header information
        ncache_header = NetcacheHeader(pkt[UDP].payload)
        op = self.int_to_packed(ncache_header.op, max_width=8)
        key = self.int_to_packed(ncache_header.key, max_width=128)
        value = self.int_to_packed(ncache_header.value, max_width=1024)
        # if value field is empty then do not insert to cache
        if not value:
            return
        # insert the key value pair of the hot report to cache
        # self.insert_value(key,value)


    def hot_reports_loop(self):
        cpu_port_intf = str(self.topo.get_cpu_port_intf(self.sw_name))
        sniff(iface=cpu_port_intf, prn=self.recv_hot_report, filter="udp port 50000")


    def main(self):
        self.set_value_tables()
        self.dummy_populate_vtables()
        self.hot_reports_loop()

if __name__ == "__main__":
    controller = NCacheController('s1').main()
