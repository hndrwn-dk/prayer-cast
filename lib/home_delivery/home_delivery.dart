/// Home delivery layer: presence → coordination → cast.
///
/// Public barrel for the module layout in spec §7. Subsystems:
/// - [presence] — is the user home?
/// - [coordination] — which device plays?
/// - [delivery] — how audio reaches the speaker?
///
/// Dependency rule: `presence` and `coordination` must not import `delivery`.
/// Only [DeliveryOrchestrator] knows about all three.
library;

export 'common/clock.dart';
export 'common/logger.dart';
export 'common/scheduler.dart';
export 'coordination/clock_skew.dart';
export 'coordination/device_identity.dart';
export 'coordination/election.dart';
export 'coordination/election_auth.dart';
export 'coordination/election_message.dart';
export 'coordination/election_schedule.dart';
export 'coordination/peer_registry.dart';
export 'coordination/session_id.dart';
export 'coordination/unicast_transport.dart';
export 'delivery/cast_client.dart';
export 'delivery/delivery_orchestrator.dart';
export 'delivery/interface_selector.dart';
export 'delivery/media_server.dart';
export 'logging/delivery_database.dart';
export 'logging/delivery_database_open.dart';
export 'logging/delivery_log_dao.dart';
export 'logging/delivery_log_table.dart';
export 'logging/outcome.dart';
export 'logging/outcome_explanation.dart';
export 'coordinator/adzan_audio_loader.dart';
export 'coordinator/delivery_settings.dart';
export 'coordinator/home_delivery_runtime.dart';
export 'coordinator/next_prayer_provider.dart';
export 'coordinator/prayer_delivery_coordinator.dart';
export 'platform/audio_keepalive.dart';
export 'platform/device_conditions.dart';
export 'platform/exact_alarm.dart';
export 'platform/network_prefix.dart';
export 'platform/oem_battery_settings.dart';
export 'ui/delivery_log_page.dart';
export 'ui/delivery_log_providers.dart';
export 'ui/icons/premium_icons.dart';
export 'ui/outcome_status.dart';
export 'ui/theme/atmosphere_background.dart';
export 'ui/theme/prayer_cast_colors.dart';
export 'ui/theme/prayer_cast_theme.dart';
export 'ui/widgets/premium_mark.dart';
export 'presence/fingerprint_store.dart';
export 'presence/lan_fingerprint.dart';
export 'presence/mdns_browser.dart';
export 'presence/presence_schedule.dart';
export 'presence/presence_service.dart';
export 'presence/presence_state.dart';
