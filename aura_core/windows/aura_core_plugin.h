#ifndef FLUTTER_PLUGIN_AURA_CORE_PLUGIN_H_
#define FLUTTER_PLUGIN_AURA_CORE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace aura_core {

class AuraCorePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  AuraCorePlugin();

  virtual ~AuraCorePlugin();

  // Disallow copy and assign.
  AuraCorePlugin(const AuraCorePlugin&) = delete;
  AuraCorePlugin& operator=(const AuraCorePlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace aura_core

#endif  // FLUTTER_PLUGIN_AURA_CORE_PLUGIN_H_
