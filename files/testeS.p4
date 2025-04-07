#if __TARGET_TOFINO__ == 2
#include <t2na.p4>
#else
#include <tna.p4>
#endif

#include "headers.p4"

const bit<64> clk_id = 64w0x1234567812345678;

struct metadata{
	bit<48> time;
	gptp_type_t gptp_type;
	MirrorId_t ing_mir_ses;   // Ingress mirror session ID
	bit<8> ctrl;
}

parser IngressParser(
		packet_in packet,
		out headers hdr,
		out metadata md,
		out ingress_intrinsic_metadata_t intr_md){
	state start {
		packet.extract(intr_md);
		packet.advance(PORT_METADATA_SIZE);
		
		pktgen_timer_header_t pktgen_pd_hdr = packet.lookahead<pktgen_timer_header_t>();
		transition select(pktgen_pd_hdr.app_id) {
			3 : parse_pktgen_req;
			//2 : parse_pktgen_sync;
			default : mark_to_drop;
			//default : parse_ethernet;
		}
	}
		
		
	state parse_pktgen_req{
		//packet.extract(hdr.gen);
		packet.extract(hdr.ethernet);
		md.ctrl = 2;
		md.gptp_type = GPTP_PDELAY_REQ;
        transition accept;
	}

	state parse_ethernet{
		packet.extract(hdr.ethernet);		
		transition select(hdr.ethernet.ether_type) {
			ETHERTYPE_GPTP : parse_gptp;
			default: reject;
		}      
	}

	state parse_gptp{
		packet.extract(hdr.gptp_base);
		transition select(hdr.gptp_base.gptp_message) {
			GPTP_PDELAY_RESP : parse_gptp_resp;
			default: reject;
		}      
	}

	state parse_gptp_resp{
		packet.extract(hdr.gptp_resp);
		md.gptp_type = GPTP_PDELAY_RESP;
		transition accept;
	}

	state mark_to_drop{		
		md.ctrl = 1;		
        transition accept;
	}

}

control Ingress(
		inout headers hdr,
		inout metadata md,
		in ingress_intrinsic_metadata_t md2,
		in ingress_intrinsic_metadata_from_parser_t parser_md,
		inout ingress_intrinsic_metadata_for_deparser_t deparser_md,
		inout ingress_intrinsic_metadata_for_tm_t tm_md){



	Register <bit<32>, bit<1>> (32w1) time_ing;

	RegisterAction<bit<32>, bit<1>, bit<32>>(time_ing) get_time_ing = {
		void apply(inout bit<32> reg, out bit<32>  ret) {
			ret = reg;
			reg = hdr.gptp_resp.timestamp[31:0];
		}
    };

	action drop() {
		deparser_md.drop_ctl = 0x1;
  	}
	action match(PortId_t port) {
		tm_md.ucast_egress_port = 160;
		//ig_intr_tm_md.bypass_egress = 1w1;
  	}

	table t {
		key = {
			md.ctrl : exact;
		}
		actions = {
			match;
			@defaultonly drop;
		}
		const default_action = drop();
		size = 1500;
	}

	apply{

		// headers comuns de pacote gPTP. Verificar importancia depois
		//hdr.gen.setInvalid();
		hdr.ethernet.dst_addr = 0xAA_AA_AA_AA_AA_AA;
		hdr.ethernet.src_addr = 0xBB_BB_BB_BB_BB_BB;
		hdr.ethernet.ether_type = ETHERTYPE_GPTP;		
		hdr.gptp_base.setValid();
		hdr.gptp_base.majorSdoId = 0;		
		hdr.gptp_base.minor_version_ptp = 1;
		hdr.gptp_base.version_ptp = 2;
		hdr.gptp_base.domain_number = 1;
		hdr.gptp_base.minorSdoId = 0;
		hdr.gptp_base.flags = 0;
		hdr.gptp_base.correction_field[47:0] = parser_md.global_tstamp; // por enquanto inutil
		hdr.gptp_base.msg_type_specific = 0;
		hdr.gptp_base.clock_identity = 0;
		hdr.gptp_base.source_port_id = 160;
		hdr.gptp_base.sequence_id = 0;
		hdr.gptp_base.control_field = 0;
		hdr.gptp_base.log_msg_period = 0;
		
		// Tipo de mensagem gPTP tratada no ingress
		hdr.gptp_base.gptp_message = md.gptp_type;

		// Tempo do ingress
		md.time[47:0] = parser_md.global_tstamp[47:0];

		t.apply();		
			//tm_md.ucast_egress_port = 130; // necos
			 // vou enviar						
		if(md.gptp_type==GPTP_PDELAY_REQ){
			hdr.gptp_base.msg_length = 54;		
			hdr.gptp_req.setValid();			
			//get_time_ing.execute(0);
		}
		if(md.ctrl==1){
			tm_md.ucast_egress_port = 0;
		}
	}
}

control IngressDeparser(
		packet_out packet,
		inout headers hdr,
		in metadata md,
		in ingress_intrinsic_metadata_for_deparser_t deparser_md){
	
	Mirror() mirror;
	
	apply{
		if (deparser_md.mirror_type == 1) { // check mirror_type
			mirror.emit(md.ing_mir_ses);
		}
		if (deparser_md .mirror_type == 2) {
			mirror.emit(md.ing_mir_ses);
		}
		packet.emit(hdr);
		
	}
}

parser EgressParser(
		packet_in packet,
		out headers hdr,
		out metadata md,
		out egress_intrinsic_metadata_t md2){

	state start {
		packet.extract(md2);
		packet.extract(hdr.ethernet);		
		transition select(hdr.ethernet.ether_type) {
			ETHERTYPE_GPTP : parse_gptp;
			default: mark_to_drop;
		}      
	}

	state parse_gptp{
		packet.extract(hdr.gptp_base);
		transition select(hdr.gptp_base.gptp_message) {
			GPTP_PDELAY_REQ : parse_gptp_req;
			default: mark_to_drop;
		}      
	}

	state parse_gptp_req{
		packet.extract(hdr.gptp_req);
		transition accept;
	}
	
	state mark_to_drop{		
		md.ctrl = 1;		
        transition reject;
	}

}

control Egress(
		inout headers hdr,
		inout metadata md,
		in egress_intrinsic_metadata_t md2,
		in egress_intrinsic_metadata_from_parser_t parser_md,
		inout egress_intrinsic_metadata_for_deparser_t deparser_md,
		inout egress_intrinsic_metadata_for_output_port_t output_port_md){

	Register <bit<32>, bit<1>> (32w1) peer_delay_aux;
	Register <bit<32>, bit<1>> (32w1) peer_delay;

	RegisterAction<bit<32>, bit<1>, bit<32>>(peer_delay_aux) get_t1 = {
		void apply(inout bit<32> reg, out bit<32>  ret) {
			ret = reg;
			reg = parser_md.global_tstamp[31:0];
		}
    };
	RegisterAction<bit<32>, bit<1>, bit<32>>(peer_delay_aux) get_t4_t1 = {
		void apply(inout bit<32> reg, out bit<32>  ret) {
			ret = reg;
			reg = md.time[31:0] - reg;
		}
    };


	apply{
		if(md.ctrl==2){
			get_t1.execute(0);
		}if(md.gptp_type==GPTP_PDELAY_RESP){
			get_t4_t1.execute(0);
		}
	}
}

control EgressDeparser(
		packet_out packet,
		inout headers hdr,
		in metadata eg_md,
		in egress_intrinsic_metadata_for_deparser_t deparser_md){
	apply{
		packet.emit(hdr);	
	}
}

Pipeline(IngressParser(),Ingress(),IngressDeparser(),EgressParser(),Egress(),EgressDeparser()) pipe;

Switch(pipe) main;
