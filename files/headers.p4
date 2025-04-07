#ifndef _HEADERS_
#define _HEADERS_

typedef bit<48> mac_addr_t;

typedef bit<16> ether_type_t;
const ether_type_t ETHERTYPE_IPV4 = 16w0x0800;
const ether_type_t ETHERTYPE_ARP = 16w0x0806;
const ether_type_t ETHERTYPE_IPV6 = 16w0x86dd;
const ether_type_t ETHERTYPE_VLAN = 16w0x8100;
const ether_type_t ETHERTYPE_GPTP = 16w0x88F7;

typedef bit<4> gptp_type_t;
const gptp_type_t GPTP_SYNC = 4w0x0;
const gptp_type_t GPTP_FOLLOW_UP = 4w0x8;
const gptp_type_t GPTP_PDELAY_REQ = 4w0x2;
const gptp_type_t GPTP_PDELAY_RESP = 4w0x3;
const gptp_type_t GPTP_PDELAY_RESP_FOLLOW_UP = 4w0xa;

typedef bit<256> tlv_type_t;


header ethernet_t {
    mac_addr_t dst_addr;
    mac_addr_t src_addr;
    ether_type_t ether_type;
}

header tlv_h{
    bit<16> tlv_type;
    bit<16> length_field;
    bit<24> orgazination_id;
    bit<24> orgazination_subtype;
    bit<32> cumulative_scaled_rate_offset;
    bit<16> gm_time_base_indicator;
    bit<96> last_gm_phase_change;
    bit<32> scaled_last_gm_freq_change;
}

header gptp_t{
    bit<4> majorSdoId;
    gptp_type_t gptp_message;
    bit<4> minor_version_ptp;
    bit<4> version_ptp;
    bit<16> msg_length;
    bit<4> domain_number;
    bit<4> minorSdoId;
    bit<16> flags;
    bit<64> correction_field;
    bit<32> msg_type_specific;
    bit<64> clock_identity;
    bit<16> source_port_id;
    bit<16> sequence_id;
    bit<16> control_field;
    bit<8> log_msg_period;
}


header gptp_sync_h{
    bit<80> reservado;
}

header gptp_sync_follow_up_h{
    bit<80> precise_origin_time_stamp;
    tlv_type_t follow_up_tlv;
}

header gptp_req_h{
    bit<80> timestamp;
    bit<80> unused;
}

header gptp_resp_h{
    bit<80> timestamp;
    bit<64> req_source_port_identity;
    bit<16> req_source_port_id2;
}


struct headers {
    pktgen_timer_header_t gen;
    ethernet_t ethernet;
    gptp_t gptp_base;
    gptp_req_h gptp_req;
    gptp_resp_h gptp_resp;
    gptp_sync_h gptp_sync;
    gptp_sync_follow_up_h gptp_sync_follow_up;
}


struct empty_header_t {}

struct empty_metadata_t {}

#endif /* _HEADERS_ */