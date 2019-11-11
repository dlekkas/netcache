#ifndef PARSERS_P4
#define PARSERS_P4

#include "headers.p4"

parser MyParser(packet_in packet, out headers hdr, inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType){
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol){
            TYPE_TCP : parse_tcp;
			TYPE_UDP : parse_udp;
            default: accept;
        }
    }

    state parse_tcp {
        packet.extract(hdr.tcp);
        transition select(hdr.tcp.dstPort) {
			NETCACHE_PORT : parse_netcache;
			default: accept;
		}
    }

	state parse_udp {
		packet.extract(hdr.udp);
		transition select(hdr.udp.dstPort) {
			NETCACHE_PORT : parse_netcache;
			default: accept;
		}
	}

	state parse_netcache {
		/* TODO #1(dimlek): enforce in some way that write queries are TCP */
		/* TODO #2(dimlek): decide how many bytes to extract for value field */
		packet.extract(hdr.netcache);
		transition accept;
	}

}

/*************************************************************************
***********************  D E P A R S E R  *****************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {

    	packet.emit(hdr.ethernet);
		packet.emit(hdr.ipv4);
		packet.emit(hdr.tcp);
		packet.emit(hdr.udp);
		packet.emit(hdr.netcache);

    }
}


#endif     // PARSERS_P4
