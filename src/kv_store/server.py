import socket
import logging
import threading
import time
import sys

import threading

from scapy.all import *

LOGGING_FILE = 'server.log'

logging.basicConfig(
        filename=LOGGING_FILE,
        format='%(asctime)s %(levelname)-8s %(message)s',
        level=logging.DEBUG,
        datefmt='%d-%m-%Y %H:%M:%S')

NETCACHE_READ_QUERY = 0
NETCACHE_WRITE_QUERY = 1
NETCACHE_DELETE_QUERY = 2


class KVServer:

    def __init__(self, host, port, max_listen=10):
        # simple in-memory key value store, represented by a dictionary
        self.kv_store = {}
        # server ip address
        self.host = host
        # port server is listening to
        self.port = port
        # server socket
        self.ss = None
        # max clients to listen to
        self.max_listen = max_listen


    def activate(self):
        # create socket server and start listening on specified port
        self.ss = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.ss.bind((self.host, self.port))

        logging.info('Key-Value store server started listening on port ' + str(self.port))

        while True:
            # spawn new thread for each incoming connection
            #server_t = threading.Thread(target=self.handle_client_request)
            #server_t.setDaemon(True)
            #server_t.start()
            self.handle_client_request()


    def handle_client_request(self):
        # netcache_pkt is an array of bytes belonging to incoming packet's data
        # the data portion of the packet represents the netcache header, so we
        # can extract all the fields defined in the netcache custom protocol
        netcache_pkt, addr = self.ss.recvfrom(1024)
        op = netcache_pkt[0]
        seq = netcache_pk[1:5]
        key = netcache_pkt[5:21]

        if key == NETCACHE_READ_QUERY:
            cache_read(key)
        elif key == NETCACHE_WRITE_QUERY:
            val = netcache_pkt[21:]
            cache_write(key, val)
        elif key == NETCACHE_DELETE_QUERY:
            cache_delete(key)
        else
            logging.info('Unsupported query type received from client ' + addr)


    # write value for a given key to netcache
    def cache_write(self, key, value):
        pass


    # read value for a given key from netcache
    def cache_read(self, key):
        pass


    # delete value for a given key from netcache
    def cache_delete(self, key):
        pass


server = KVServer('127.0.0.1', 40007)
server.activate()



