Based on https://github.com/ejbills/mediaremote-adapter at
5b6afde3f501a3da567e23bf7f23d562938a1809. Original copyright notices are retained.

Local patch: capability lookup using MRMediaRemoteGetSupportedCommandsForOrigin,
per-command enablement, coherent PID-checked snapshots with generation tokens,
guarded and bundle-targeted transport. No package cache modifications.
Private SPI signatures checked against WebKit's MediaRemoteSoftLink.h and
MediaSession.mm. Missing symbols fail closed and remain distinguishable from
an explicit unsupported/disabled command. Payloads and errors never log metadata.
