#include "include/aura_core/aura_core_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "aura_core_plugin.h"

void AuraCorePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  aura_core::AuraCorePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
