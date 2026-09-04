extends MultiplayerPeerExtension
class_name FusionMultiplayerPeer

# ID gap to simulate godot's "default" id randomization (and to not interfere with master id 1)
const ID_GAP = 100

var _refuse_new_connections: bool = false
var _target_peer: int
var _transfer_mode: MultiplayerPeer.TransferMode
var _packet_array: Array[PacketData] = []
var master_client_id: int = 1
var fusion_id_to_peer_id: Dictionary[int, int] = {}
var peer_id_to_fusion_id: Dictionary[int, int] = {}

var _rpc_relay: FusionRpcRelay

func _init() -> void:
	_rpc_relay = FusionRpcRelay.new()
	_rpc_relay.name = "FusionRelay"
	_rpc_relay._m_peer = self
	var parent := (Engine.get_main_loop() as SceneTree).root
	parent.call_deferred("add_child", _rpc_relay, true)
	
	Fusion.player_joined.connect(_player_joined)
	Fusion.player_left.connect(_player_left)
	Fusion.room_joined.connect(_room_joined)
	Fusion.room_left.connect(_room_left)
	Fusion.master_client_changed.connect(_master_client_changed)

func _player_joined(player_id: int, _user_id: String) -> void:
	var peer_id := player_id + ID_GAP
	_add_peer(player_id, peer_id)
	peer_connected.emit(peer_id)

func _player_left(player_id: int, _is_inactive: bool) -> void:
	if fusion_id_to_peer_id.has(player_id):
		var peer_id := fusion_id_to_peer_id[player_id]
		peer_disconnected.emit(peer_id)
		_remove_peer_from_fusion_id(player_id)

func _room_joined() -> void:
	_rpc_relay.request_master_client_id()

func _received_master_id(id: int) -> void:
	master_client_id = id
	_add_peer(master_client_id, 1)
	_emit_connected()

func _emit_connected() -> void:
	peer_connected.emit(1)

func _room_left() -> void:
	peer_disconnected.emit(1)

func _add_peer(fusion_id: int, peer_id: int) -> void:
	# fusion_id peer was previously held by a different peer_id
	if fusion_id_to_peer_id.has(fusion_id):
		var old_peer_id := fusion_id_to_peer_id[fusion_id]
		if old_peer_id != peer_id:
			peer_id_to_fusion_id.erase(old_peer_id)
			peer_disconnected.emit(old_peer_id)

	# peer_id was previously held by a different fusion_id
	if peer_id_to_fusion_id.has(peer_id):
		var old_fusion_id := peer_id_to_fusion_id[peer_id]
		if old_fusion_id != fusion_id:
			fusion_id_to_peer_id.erase(old_fusion_id)

	fusion_id_to_peer_id[fusion_id] = peer_id
	peer_id_to_fusion_id[peer_id] = fusion_id
	peer_connected.emit(peer_id)

func _remove_peer_from_fusion_id(fusion_id: int) -> void:
	if fusion_id_to_peer_id.has(fusion_id):
		var peer_id := fusion_id_to_peer_id[fusion_id]
		fusion_id_to_peer_id.erase(fusion_id)
		peer_id_to_fusion_id.erase(peer_id)

func _master_client_changed(new_master_id: int, _old_master_id: int) -> void:
	master_client_id = new_master_id
	_add_peer(master_client_id, 1)

func _close() -> void:
	Fusion.leave_room()

func _disconnect_peer(_p_peer: int, _p_force: bool) -> void:
	# Not supported
	return

func _is_server() -> bool:
	return Fusion.is_master_client()

func _poll() -> void:
	# Not supported
	return

func _get_unique_id() -> int:
	return fusion_id_to_peer_id.get(Fusion.get_local_player_id(), -1)

func _set_refuse_new_connections(p_enable: bool) -> void:
	_refuse_new_connections = p_enable

func _is_refusing_new_connections() -> bool:
	return _refuse_new_connections

func _is_server_relay_supported() -> bool:
	return false

func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	var status := Fusion.get_connection_status()
	match status:
		Fusion.ConnectionStatus.STATUS_DISCONNECTED:
			return MultiplayerPeer.ConnectionStatus.CONNECTION_DISCONNECTED
		Fusion.ConnectionStatus.STATUS_ERROR:
			return MultiplayerPeer.ConnectionStatus.CONNECTION_DISCONNECTED
		Fusion.ConnectionStatus.STATUS_IN_ROOM:
			return MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED
	return MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTING

func _get_available_packet_count() -> int:
	return _packet_array.size()

func _get_max_packet_size() -> int:
	return 0

func _get_packet_script() -> PackedByteArray:
	return _packet_array.pop_front().data

func _put_packet_script(p_buffer: PackedByteArray) -> Error:
	_rpc_relay.put_packet(_target_peer, p_buffer)
	return OK

func _get_packet_channel() -> int:
	return 0

func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return MultiplayerPeer.TRANSFER_MODE_RELIABLE

func _get_packet_peer() -> int:
	return _packet_array.front().from_peer

func _get_transfer_channel() -> int:
	return 0

func _set_transfer_channel(_p_channel: int) -> void:
	# Not supported
	return

func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _transfer_mode

func _set_transfer_mode(p_mode: MultiplayerPeer.TransferMode) -> void:
	_transfer_mode = p_mode

func _set_target_peer(p_peer: int) -> void:
	_target_peer = p_peer

func _add_packet(p_data: PacketData) -> void:
	_packet_array.append(p_data)

class PacketData:
	var from_peer: int
	var data: PackedByteArray
