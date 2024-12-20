# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.blacklistedKernelModules = [ "dvb_usb_rtl28xxu" ];

  services.udev.packages = [ pkgs.rtl-sdr ];

  boot.extraModulePackages = [ pkgs.linuxPackages.asus-wmi-sensors ];

  boot.kernelModules = [ "asus-wmi-sensors" ];

  boot.extraModprobeConfig = ''
    options snd_usb_audio device_setup=1
  '';

  networking.hostName = "zoomer";

  networking.wireless.environmentFile = "/run/secrets/wireless.env";

  networking.wireless = {
    enable = false; # Enables wireless support via wpa_supplicant.
    userControlled.enable = false;
    networks = {
      badgerfields = {
        psk = "@PSK_BADGERFIELDS@";
      };
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/London";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.enp6s0.useDHCP = false;
  networking.interfaces.enp8s0.useDHCP = true;
  networking.interfaces.wlp7s0.useDHCP = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  #  networking.interfaces = {
  #   enp6s0.useDHCP = true;
  #   enp8s0 = {
  #     useDHCP = false;
  #     mtu = 9000;
  #     ipv4.addresses = [{address = "10.0.0.2"; prefixLength = 24;}];
  #   };
  #   wlp7s0.useDHCP = true;
  # };
  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "uk";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the Plasma 5 Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;

  # Configure keymap in X11
  services.xserver.xkb.layout = "gb";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.gutenprint ];
  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  hardware.rtl-sdr.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  services.prometheus = {
    enable = true;
    exporters.node.enable = true;
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ]; }
        ];
      }
    ];
  };

  environment.etc = with pkgs; {
    "grafana/dashboards/hwmon.json" = {
      mode = "0444";
      source = ./dashboards/hwmon.json;
    };
    "jdk".source = temurin-jre-bin;
  };

  services.grafana = {
    settings = { };
    enable = true;
    provision = {
      enable = true;
      datasources = {
        settings = {
          datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              isDefault = true;
              url = "http://127.0.0.1:${toString config.services.prometheus.port}";
            }
          ];
        };
      };
      dashboards = {
        settings = {
          providers = [
            {
              name = "provisioned-dashboards";
              options.path = "/etc/grafana/dashboards/";
            }
          ];
        };
      };
    };
  };

  users.groups = {
    ed = {
      gid = 1000;
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.ed = {
    isNormalUser = true;
    group = "ed";
    extraGroups = [
      "wheel"
      "users"
      "dialout"
      "plugdev"
    ];
    shell = pkgs.zsh;
  };

  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget
    vim
    firefox
    linuxPackages.asus-wmi-sensors
    lm_sensors
    chromium
    git
    gparted
    vscode
    vlc
    #     kicad
    keepassxc
    #     kodi
    transmission
    filezilla
    docker
    docker-compose
    #     vulkan-tools
    virtualboxWithExtpack
    kcalc
    ark
    ardour
    cmake
    minicom
    picocom
    radeon-profile
    glxinfo
    dropbox
    yosys
    nextpnr
    icestorm
    gnumake
    #     rustup
    #     zoom-us
    tree
    jetbrains.idea-community
    openjdk
    guvcview
    v4l-utils
    obs-studio
    hugo
    nix-prefetch-scripts
    #     spectacle
    ffmpeg-full
    kdenlive
    awscli2
    gtkwave
    verilog
    usbutils
    nixfmt-rfc-style
  ];

  fileSystems."/mnt/tank" = {
    device = "orinoco.badgerfields.internal:/export/tank";
    fsType = "nfs";
    options = [ "auto" "x-systemd.automount" "x-systemd.device-timeout=10" "timeo=14" "x-systemd.idle-timeout=1min" ];
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };
  programs.steam.enable = true;
  programs.zsh.enable = true;
  programs.java = {
    enable = true;
    package = pkgs.openjdk;
  };
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?

}
