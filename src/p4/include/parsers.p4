#ifndef PARSERS_P4
#define PARSERS_P4

#include "headers.p4"

// modified version of https://github.com/jafingerhut/p4-guide/tree/master/tcp-options-parser
// enables parser to process tcp header options
parser Tcp_option_parser(packet_in b,
                         in bit<4> tcp_hdr_data_offset,
                         out Tcp_option_stack vec,
                         out Tcp_option_padding_h padding)
{
    bit<7> tcp_hdr_bytes_left;

    state start {
        // RFC 793 - the Data Offset field is the length of the TCP
        // header in units of 32-bit words.  It must be at least 5 for
        // the minimum length TCP header, and since it is 4 bits in
        // size, can be at most 15, for a maximum TCP header length of
        // 15*4 = 60 bytes.
        verify(tcp_hdr_data_offset >= 5, error.TcpDataOffsetTooSmall);
        tcp_hdr_bytes_left = 4 * (bit<7>) (tcp_hdr_data_offset - 5);
        // always true here: 0 <= tcp_hdr_bytes_left <= 40
        transition next_option;
    }
    state next_option {
        transition select(tcp_hdr_bytes_left) {
            0 : accept;  // no TCP header bytes left
            default : next_option_part2;
        }
    }
    state next_option_part2 {
        // precondition: tcp_hdr_bytes_left >= 1
        transition select(b.lookahead<bit<8>>()) {
            0: parse_tcp_option_end;
            1: parse_tcp_option_nop;
            2: parse_tcp_option_ss;
            3: parse_tcp_option_s;
            4: parse_tcp_option_sack_p;
            5: parse_tcp_option_sack;
            8: parse_tcp_option_timestamp;
        }
    }
    state parse_tcp_option_end {
        b.extract(vec.next.end);
        // TBD: This code is an example demonstrating why it would be
        // useful to have sizeof(vec.next.end) instead of having to
        // put in a hard-coded length for each TCP option.
        tcp_hdr_bytes_left = tcp_hdr_bytes_left - 1;
        transition consume_remaining_tcp_hdr_and_accept;
    }
    state consume_remaining_tcp_hdr_and_accept {
        // A more picky sub-parser implementation would verify that
        // all of the remaining bytes are 0, as specified in RFC 793,
        // setting an error and rejecting if not.  This one skips past
        // the rest of the TCP header without checking this.

        // tcp_hdr_bytes_left might be as large as 40, so multiplying
        // it by 8 it may be up to 320, which requires 9 bits to avoid
        // losing any information.
        b.extract(padding, (bit<32>) (8 * (bit<9>) tcp_hdr_bytes_left));
        transition accept;
    }
    state parse_tcp_option_nop {
        b.extract(vec.next.nop);
        tcp_hdr_bytes_left = tcp_hdr_bytes_left - 1;
        transition next_option;
    }
    state parse_tcp_option_ss {
        verify(tcp_hdr_bytes_left >= 4, error.TcpOptionTooLongForHeader);
        tcp_hdr_bytes_left = tcp_hdr_bytes_left - 4;
        b.extract(vec.next.ss);
        transition next_option;
    }
    state parse_tcp_option_s {
        verify(tcp_hdr_bytes_left >= 3, error.TcpOptionTooLongForHeader);
        tcp_hdr_bytes_left = tcp_hdr_bytes_left - 3;
        b.extract(vec.next.s);
        transition next_option;
    }
    state parse_tcp_option_sack_p {
        verify(tcp_hdr_bytes_left >= 2, error.TcpOptionTooLongForHeader);
        tcp_hdr_bytes_left = tcp_hdr_bytes_left - 2;
        b.extract(vec.next.sack_p);
        transition next_option;
    }
    state parse_tcp_option_sack {
        bit<8> n_sack_bytes = b.lookahead<Tcp_option_sack_top>().length;
        // I do not have global knowledge of all TCP SACK
        // implementations, but from reading the RFC, it appears that
        // the only SACK option lengths that are legal are 2+8*n for
        // n=1, 2, 3, or 4, so set an error if anything else is seen.
        verify(n_sack_bytes == 10 || n_sack_bytes == 18 ||
               n_sack_bytes == 26 || n_sack_bytes == 34,
               error.TcpBadSackOptionLength);
        verify(tcp_hdr_bytes_left >= (bit<7>) n_sack_bytes,
               error.TcpOptionTooLongForHeader);
        tcp_hdr_bytes_left = tcp_hdr_bytes_left - (bit<7>) n_sack_bytes;
        b.extract(vec.next.sack, (bit<32>) (8 * n_sack_bytes - 16));
        transition next_option;
    }

    state parse_tcp_option_timestamp {
        verify(tcp_hdr_bytes_left >= 10, error.TcpOptionTooLongForHeader);
        tcp_hdr_bytes_left = tcp_hdr_bytes_left - 10;
        b.extract(vec.next.ts);
        transition next_option;
    }
}

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
		meta.tcpLength = hdr.ipv4.totalLen - 4 * (bit<16>) hdr.ipv4.ihl;

		transition select(hdr.tcp.dataOffset, hdr.tcp.dstPort, hdr.tcp.srcPort) {
			(5, NETCACHE_PORT, _): parse_netcache;
			(5, _, NETCACHE_PORT): parse_netcache;
			(5, _, _) : accept;
			default: parse_tcp_options;
		}

		/*
        Tcp_option_parser.apply(packet, hdr.tcp.dataOffset,
                                //hdr.tcp_options_vec, hdr.tcp_options_padding);


        bit<16> tcp_payload_len = hdr.ipv4.totalLen - 4 * (bit<16>) hdr.ipv4.ihl - 4 * (bit<16>) hdr.tcp.dataOffset;
        transition select(tcp_payload_len, hdr.tcp.dstPort, hdr.tcp.srcPort) {
			(0, _, _) : accept;
			(_, _, NETCACHE_PORT): parse_netcache;
            (_, NETCACHE_PORT,_): parse_netcache;
			default: accept;
		}
		*/
    }

	state parse_tcp_options {
		bit<10> len = ((bit<10>) (hdr.tcp.dataOffset - 5) * 4 * 8);
		packet.extract(hdr.tcp_options, (bit<32>) len);

		transition select (hdr.tcp.dstPort, hdr.tcp.srcPort) {
			(NETCACHE_PORT, _) : parse_netcache;
			(_, NETCACHE_PORT) : parse_netcache;
			default: accept;
		}
	}

	state parse_udp {
		packet.extract(hdr.udp);
		transition select(hdr.udp.dstPort, hdr.udp.srcPort) {
			(NETCACHE_PORT, _) : parse_netcache;
			(_, NETCACHE_PORT) : parse_netcache;
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
		packet.emit(hdr.tcp_options);
        //packet.emit(hdr.tcp_options_vec);
        //packet.emit(hdr.tcp_options_padding);
		packet.emit(hdr.udp);
		packet.emit(hdr.netcache);

    }
}


#endif     // PARSERS_P4
