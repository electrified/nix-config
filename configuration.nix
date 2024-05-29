# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = ["zfs"];
  #boot.kernelPackages = pkgs.linuxPackages_5_15;

  networking.hostName = "orinoco"; # Define your hostname.
  networking.hostId = "b310b4df";
  networking.wireless = {
    environmentFile = "/root/secrets/wireless.env";
    enable = true;
    networks = {
       badgerfields = {
         psk = "@PSK_BADGERFIELDS@";
       };
    };
  };

nixpkgs.config.allowUnfree = true;
  
  # ip forwarding
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
#set ips

  networking.interfaces = {
 #10GBE
  enp2s0 = {
  useDHCP=false;
  ipv4 = {addresses = [{address="192.168.10.1"; prefixLength=24;}];};
  };
 # Onboard
  enp5s0 = {
useDHCP=false;
  };
  # Intel Gbe PCIe 
  enp9s0 = {
useDHCP=false;
  ipv4 = {addresses = [{address="192.168.20.1"; prefixLength=24;}];};
  };
  wlp4s0 = {
    useDHCP=true;
};
  };

networking.firewall = {
trustedInterfaces = ["enp2s0" "enp5s0" "enp9s0"];
};

#dhcp server
services.dnsmasq = {
enable = true;
extraConfig = "interface=lo,enp2s0,enp9s0\n
bind-interfaces\n
domain=home.lan\n
dhcp-range=192.168.10.2,192.168.10.200,12h\n
dhcp-range=192.168.20.2,192.168.20.200,12h\n
dhcp-host=00:c0:b7:cf:8f:d5,192.168.20.10";
#dhcp-option=192.168.2.2,option:
};

  fileSystems."/export/tank" =
    { device = "/tank";
      options = ["bind"];
    };

  fileSystems."/export/tank/media" =
    { device = "/tank/media";
      options = ["bind"];
    };

  fileSystems."/export/tank/storage" =
    { device = "/tank/storage";
      options = ["bind"];    
    };

  fileSystems."/export/tank/media/video" =
    { device = "/tank/media/video";
      options = ["bind"];
    };

  fileSystems."/export/tank/media/audio" =
    { device = "/tank/media/audio";
      options = ["bind"];
    };

  fileSystems."/export/tank/storage/rom_share" =
    { device = "/tank/storage/rom_share";
      options = ["bind"];
    };



#zfs mounted
#nfs shares
services.nfs.server = {
enable = true;
};

services.nfs.server.exports = ''
    /export/tank         192.168.10.0/24(rw,fsid=0,no_subtree_check)
    /export/tank/storage         192.168.10.0/24(rw,nohide,insecure,no_subtree_check)
    /export/tank/media/video         192.168.10.0/24(rw,nohide,insecure,no_subtree_check)
    /export/tank/media/audio         192.168.10.0/24(rw,nohide,insecure,no_subtree_check)
    /export/tank/media         192.168.10.0/24(rw,nohide,insecure,no_subtree_check)
    /export/tank/storage/rom_share         192.168.10.0/24(rw,nohide,insecure,no_subtree_check)
'';

#samba shares
services.samba = {
  enable = true;
  securityType = "user";
  openFirewall = true;
  extraConfig = ''
    workgroup = WOMBLE
    server string = orinoco
    netbios name = orinoco
    security = user 
    #use sendfile = yes
    #max protocol = smb2
    # note: localhost is the ipv6 localhost ::1
    hosts allow = 192.168. 127.0.0.1 localhost
    hosts deny = 0.0.0.0/0
    guest account = nobody
    map to guest = bad user
  '';
  shares = {
    tank = {
      path = "/export/tank";
      browseable = "yes";
      "read only" = "no";
      "guest ok" = "no";
      "create mask" = "0644";
      "directory mask" = "0755";
#      "force user" = "ed";
#      "force group" = "ed";
    };
  };
};

services.samba-wsdd = {
  enable = true;
  openFirewall = true;
};

networking.firewall.enable = true;
networking.firewall.allowPing = true;

  # Set your time zone.
  time.timeZone = "Europe/London";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.wlp0s20u1.useDHCP = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  # };

  # Enable the X11 windowing system.
  services.xserver.enable = true;


  # Enable the Plasma 5 Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;
  

  # Configure keymap in X11
  services.xserver.layout = "gb";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.ed = {
     isNormalUser = true;
     extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
   environment.systemPackages = with pkgs; [
  #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #   wget
     firefox
     vlc
     vscode
     git
   ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}

