extends Node
class_name FusionRpcRelay

var _m_peer: FusionMultiplayerPeer

func _enter_tree() -> void:
	Fusion.register_broadcast_receiver(self)

func _exit_tree() -> void:
	if Fusion:
		Fusion.unregister_broadcast_receiver(self)

func request_master_client_id() -> void:
	Fusion.rpc_to(Fusion.TARGET_MASTER, _net_req_master_client_id)

@rpc("any_peer")
func _net_req_master_client_id() -> void:
	Fusion.rpc_to_player(Fusion.get_rpc_sender(), _net_recv_master_client_id, Fusion.get_local_player_id())

@rpc("authority")
func _net_recv_master_client_id(id: int) -> void:
	_m_peer._received_master_id(id)

func put_packet(p_peer: int, p_buffer: PackedByteArray) -> void:
	var fusion_peer: Variant = _m_peer.peer_id_to_fusion_id.get(p_peer)
	if fusion_peer:
		Fusion.rpc_to_player(fusion_peer as int, _net_put_packet, p_buffer)

@rpc("any_peer", "call_local")
func _net_put_packet(p_buffer: PackedByteArray) -> void:
	var from := Fusion.get_rpc_sender()
	if from == _m_peer.master_client_id:
		from = 1 # Override as like server were sending it
	else:
		from = _m_peer.fusion_id_to_peer_id.get(from, -1)
	var data := _m_peer.PacketData.new()
	data.from_peer = from
	data.data = p_buffer
	
	_m_peer._add_packet(data)
