#ifndef RTORRENT_CONTROL_H
#define RTORRENT_CONTROL_H

#include <atomic>
#include <cinttypes>
#include <sys/types.h>
#include <torrent/torrent.h>
#include <torrent/utils/scheduler.h>

namespace ui {
  class Root;
}

namespace core {
  class Manager;
  class ViewManager;
  class DhtManager;
}

namespace display {
  class Manager;
}

namespace input {
  class InputEvent;
  class Manager;
}

namespace rpc {
  class CommandScheduler;
  class XmlRpc;
  class object_storage;
  class LuaEngine;
}

namespace torrent {
  class directory_events;
}

class Control {
public:
  Control();
  ~Control();

  bool                is_shutdown_completed();
  bool                is_shutdown_received()        { return m_shutdownReceived; }
  bool                is_shutdown_started()         { return m_shutdownQuick; }

  void                initialize();
  void                cleanup();
  void                cleanup_exception();

  void                handle_shutdown();

  void                receive_normal_shutdown()     { m_shutdownReceived = true; }
  void                receive_quick_shutdown()      { m_shutdownReceived = true; m_shutdownQuick = true; }

  core::Manager*      core()                        { return m_core; }
  core::ViewManager*  view_manager()                { return m_viewManager; }
  core::DhtManager*   dht_manager()                 { return m_dhtManager; }

  ui::Root*           ui()                          { return m_ui; }
  display::Manager*   display()                     { return m_display; }
  input::Manager*     input()                       { return m_input; }
  input::InputEvent*  input_stdin()                 { return m_inputStdin; }

  rpc::CommandScheduler* command_scheduler()        { return m_commandScheduler; }
  rpc::object_storage*   object_storage()           { return m_objectStorage; }
  rpc::LuaEngine*        lua_engine()               { return m_lua_engine; }

  torrent::directory_events* directory_events()     { return m_directory_events; }

  uint64_t            tick() const                  { return m_tick; }
  void                inc_tick()                    { m_tick++; }

  const std::string&  working_directory() const     { return m_workingDirectory; }
  void                set_working_directory(const std::string& dir);

private:
  Control(const Control&);
  void operator = (const Control&);

  core::Manager*      m_core;
  core::ViewManager*  m_viewManager;
  core::DhtManager*   m_dhtManager;

  ui::Root*           m_ui;
  display::Manager*   m_display;
  input::Manager*     m_input;
  input::InputEvent*  m_inputStdin;

  rpc::CommandScheduler*     m_commandScheduler;
  rpc::object_storage*       m_objectStorage;
  rpc::LuaEngine*            m_lua_engine;
  torrent::directory_events* m_directory_events;

  uint64_t            m_tick;

  mode_t              m_umask;
  std::string         m_workingDirectory;

  torrent::utils::SchedulerEntry m_task_shutdown;

  std::atomic<bool>   m_shutdownReceived;
  std::atomic<bool>   m_shutdownQuick;
};

#endif
