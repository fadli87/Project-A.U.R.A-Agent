//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <aura_core/aura_core_plugin.h>
#include <objectbox_flutter_libs/objectbox_flutter_libs_plugin.h>
#include <sqlite3_flutter_libs/sqlite3_flutter_libs_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) aura_core_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "AuraCorePlugin");
  aura_core_plugin_register_with_registrar(aura_core_registrar);
  g_autoptr(FlPluginRegistrar) objectbox_flutter_libs_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "ObjectboxFlutterLibsPlugin");
  objectbox_flutter_libs_plugin_register_with_registrar(objectbox_flutter_libs_registrar);
  g_autoptr(FlPluginRegistrar) sqlite3_flutter_libs_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "Sqlite3FlutterLibsPlugin");
  sqlite3_flutter_libs_plugin_register_with_registrar(sqlite3_flutter_libs_registrar);
}
