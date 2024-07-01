{ pkgs, ... }:
let
  home = "/home/ed";
in
{
  environment.systemPackages = [ pkgs.xorg.xinit ];

  systemd.services.vncserver = {
    enable = true;
    environment = {
      PATH = pkgs.lib.mkForce "/run/wrappers/bin:${home}/.nix-profile/bin:/nix/profile/bin:${home}/.local/state/nix/profile/bin:/etc/profiles/per-user/user/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin";
    };
    unitConfig = {
      Description = "Remote desktop service (VNC)";
      After = "syslog.target network.target";
    };

    serviceConfig = {
      Type = "simple";
      User = "ed";
      WorkingDirectory = "${home}";

      ExecStartPre = "/bin/sh -c '${pkgs.tigervnc}/bin/vncserver -kill :1 > /dev/null 2>&1 || :'";
      ExecStart = "${pkgs.xorg.xinit}/bin/xinit ${home}/.vnc/xstartup -- ${pkgs.tigervnc}/bin/Xvnc :1 -interface 127.0.0.1 -rfbauth ${home}/.vnc/passwd";
      ExecStop = "${pkgs.tigervnc}/bin/vncserver -kill :1";

    };

    wantedBy = [ "multi-user.target" ];

  };
}
