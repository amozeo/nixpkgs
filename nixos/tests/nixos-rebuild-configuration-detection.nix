import ./make-test-python.nix ( {pkgs, lib, ... }: let
  methods = [
    {
      name = "flake";
      template = "flake";
      priority = 100;
      check = path: ''
        echo "$output" | grep -q "flake: ${path}"
      '';
    }
    {
      name = "by-attrset";
      template = "by-attrset";
      priority = 10;
      check = path: ''
        echo "$output" | grep -q "file: ${path}/system.nix"
      '';
    }
    {
      name = "module";
      template = "";
      priority = 0;
      check = path: ''
        echo "$output" | grep -q "file: ${path}/configuration.nix"
      '';
    }
  ];

  generatePermutationsN = n: lib.pipe methods [
    # Create list of all permutations with n elements
    (lib.replicate n)
    (domains: (lib.imap0 (i: e: {
      name = builtins.toString i;
      value = e;
    })) domains)
    lib.listToAttrs
    (lib.mapCartesianProduct (lib.attrValues))
    # remove lists that have duplicates
    (lib.filter lib.allUnique)
  ];

  script = lib.pipe methods [
    lib.length
    (lib.genList (x: generatePermutationsN (x + 1)))
    (lib.concatMap (x: x))
    # generate test for each permutation
    (lib.map (methods: let
      highestPriorityMethod = lib.foldl' (a: b: if a.priority > b.priority then a else b) (lib.head methods) methods;
      subtestName = if lib.length methods == 1 then "Check detection of ${highestPriorityMethod.name}"
        else "Check detection priority of [ ${lib.concatStringsSep " " (lib.map (method: method.name) methods)} ]";
      mergeTemplatesArg = "[ " + lib.concatStringsSep ", " (lib.map (method:
        if method.template == "" then "None" else "\"${method.template}\""
      ) methods) + " ]";
    in ''
      with subtest("${subtestName}"):
        merge_templates(${mergeTemplatesArg})
        machine.succeed("""
          output=$(nixos-rebuild -v find-config)
          echo "$output" 1>&2
          echo "$output" | grep -q "type: ${highestPriorityMethod.name}"
          ${highestPriorityMethod.check "/etc/nixos"}
        """)
        cleanup()
    ''))
    (lib.concatStringsSep "\n\n")
  ];

  subAttrSystemFile = dst: pkgs.writeText "system.nix" ''
    {
      system = import ${dst};
    }
  '';
in {
  name = "nixos-rebuild-methods";

  nodes = {
    machine = { lib, ... }: {
      imports = [
        ../modules/profiles/installation-device.nix
        ../modules/profiles/base.nix
      ];

      nix.settings = {
        substituters = lib.mkForce [ ];
        hashed-mirrors = null;
        connect-timeout = 1;
      };

      system.includeBuildDependencies = true;

      virtualisation = {
        cores = 2;
        memorySize = 2048;
      };
    };
  };

  testScript = builtins.seq script ''
    def cleanup():
      machine.succeed("rm -rf /etc/nixos")
      machine.succeed("mkdir -p /etc/nixos")

    def merge_templates(templates, out = "/etc/nixos"):
      machine.succeed("rm -rf /tmp/mixed-nixos-configuration /tmp/mixed-nixos-configuration")
      for template in templates:
        templateArg = "--template " + template if template else ""
        machine.succeed(f"nixos-generate-config {templateArg} --dir /tmp/mixed-nixos-configuration")
        machine.succeed(f"mv --update=all /tmp/mixed-nixos-configuration/* {out}")

    machine.start()
    machine.wait_for_unit("multi-user.target")
    ${script}

    with subtest("Check detection of flake through symlink"):
      machine.succeed("mkdir -p /etc/nixos-flake")
      machine.succeed("nixos-generate-config --template flake --dir /etc/nixos-flake")
      machine.succeed("ln -s /etc/nixos-flake/flake.nix /etc/nixos/flake.nix")
      machine.succeed("""
        output=$(nixos-rebuild -v find-config)
        echo "$output" 1>&2
        echo "$output" | grep -q "type: flake"
        echo "$output" | grep -q "flake: /etc/nixos-flake"
      """)
      machine.succeed("rm -rf /etc/nixos-flake")
      cleanup()

    with subtest("Check detection of system.nix file when directory was provided"):
      machine.succeed("mkdir -p /etc/nixos-system")
      machine.succeed("nixos-generate-config --template by-attrset --dir /etc/nixos-system")
      machine.succeed("""
        output=$(nixos-rebuild -v find-config --file /etc/nixos-system/system.nix)
        echo "$output" 1>&2
        echo "$output" | grep -q "type: by-attrset"
        echo "$output" | grep -q "file: /etc/nixos-system/system.nix"
      """)
      machine.succeed("rm -rf /etc/nixos-system")
      cleanup()

    with subtest("Check detection of system.nix file when --attr argument was provided"):
      machine.succeed("nixos-generate-config --template by-attrset")
      machine.succeed("mv /etc/nixos/system.nix /etc/nixos/system-but-different-name.nix")
      machine.copy_from_host("${subAttrSystemFile "/etc/nixos/system-but-different-name.nix"}", "/etc/nixos/system.nix")
      machine.succeed("""
        output=$(nixos-rebuild -v find-config --attr system)
        echo "$output" 1>&2
        echo "$output" | grep -q "type: by-attrset"
        echo "$output" | grep -q "file: /etc/nixos/system.nix"
        echo "$output" | grep -q "attribute path: system"
      """)
      machine.succeed("rm -rf /etc/nixos-system")
      cleanup()

    with subtest("Check detection of system.nix in parent directory"):
      machine.succeed("mkdir -p /etc/nixos-parent")
      machine.succeed("nixos-generate-config --template by-attrset --dir /etc/nixos-parent")
      machine.succeed("mkdir -p /etc/nixos-parent/deep/child")
      machine.succeed("""
        cd /etc/nixos-parent/deep/child
        output=$(nixos-rebuild -v find-config)
        echo "$output" 1>&2
        echo "$output" | grep -q "type: by-attrset"
        echo "meow" 1>&2
        echo "$output" | grep -q "file: /etc/nixos-parent/system.nix"
      """)
      machine.succeed("rm -rf /etc/nixos-parent")
      cleanup()
  '';
})
