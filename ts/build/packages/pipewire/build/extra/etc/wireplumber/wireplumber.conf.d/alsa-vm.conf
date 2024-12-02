# ALSA node property overrides for virtual machine hardware

monitor.alsa.rules = [
  # Generic PCI cards on any VM type
  {
    matches = [
      {
        node.name = "~alsa_input.pci.*"
        cpu.vm.name = "~.*"
      }
      {
        node.name = "~alsa_output.pci.*"
        cpu.vm.name = "~.*"
      }
    ]
    actions = {
      update-props = {
        api.alsa.period-size   = 1024
        api.alsa.headroom      = 8192
      }
    }
  }
]
