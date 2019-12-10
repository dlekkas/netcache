/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#include "../include/parsers.p4"
#include "egress.p4"
#include "ingress.p4"

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}


/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
        update_checksum(
            hdr.ipv4.isValid(),
                 { hdr.ipv4.version,
                   hdr.ipv4.ihl,
                   hdr.ipv4.dscp,
                   hdr.ipv4.ecn,
                   hdr.ipv4.totalLen,
                   hdr.ipv4.identification,
                   hdr.ipv4.flags,
                   hdr.ipv4.fragOffset,
                   hdr.ipv4.ttl,
                   hdr.ipv4.protocol,
                   hdr.ipv4.srcAddr,
                   hdr.ipv4.dstAddr },
                   hdr.ipv4.hdrChecksum,
                   HashAlgorithm.csum16);

        update_checksum(
            // only update checksum of udp-netcache packets
            // that were created on the switch
            hdr.udp.isValid() && hdr.netcache.isValid(),
                {   hdr.ipv4.srcAddr,
                    hdr.ipv4.dstAddr,
                    8w0,
                    hdr.ipv4.protocol,
                    hdr.udp.len,
                    hdr.udp.srcPort,
                    hdr.udp.dstPort,
                    hdr.udp.len,
                    hdr.netcache.op,
                    hdr.netcache.seq,
                    hdr.netcache.key,
                    hdr.netcache.value },
                    hdr.udp.checksum,
                    HashAlgorithm.csum16);


		update_checksum(
			hdr.tcp.isValid() && hdr.netcache.isValid(),
			{
				hdr.ipv4.srcAddr,
				hdr.ipv4.dstAddr,
				8w0,
				hdr.ipv4.protocol,
				meta.tcpLength,
				hdr.tcp.srcPort,
				hdr.tcp.dstPort,
				hdr.tcp.seqNo,
				hdr.tcp.ackNo,
				hdr.tcp.dataOffset,
				hdr.tcp.res,
				hdr.tcp.cwr,
				hdr.tcp.ece,
				hdr.tcp.urg,
				hdr.tcp.ack,
				hdr.tcp.psh,
				hdr.tcp.rst,
				hdr.tcp.syn,
				hdr.tcp.fin,
				hdr.tcp.window,
				hdr.tcp.urgentPtr,
				hdr.tcp_options.options,
				hdr.netcache.op,
				hdr.netcache.seq,
				hdr.netcache.key,
				hdr.netcache.value
			},
			hdr.tcp.checksum,
			HashAlgorithm.csum16);



    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

//switch architecture
V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
